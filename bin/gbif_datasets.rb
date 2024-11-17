#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: gbif_datasets.rb [options]. Check and import datasets on GBIF"

  opts.on("-p", "--populate", "Populate datasets from occurrence table") do
    options[:populate] = true
  end

  opts.on("-a", "--all", "Refresh metadata for all datasets") do
    options[:all] = true
  end

  opts.on("-n", "--new", "Add metadata for new datasets, not previously downloaded") do
    options[:new] = true
  end

  opts.on("-f", "--flush", "Flush previously ingested datasets that are no longer present in occurrence data") do
    options[:flush] = true
  end

  opts.on("-x", "--remove-without-agents", "Remove datasets that do not have any agents") do
    options[:remove] = true
  end

  opts.on("-d", "--datasetkey [datasetkey]", String, "Create/update metadata for a single dataset") do |datasetkey|
    options[:datasetkey] = datasetkey
  end

  opts.on("-c", "--counter", "Rebuild occurrence counter") do
    options[:counter] = true
  end

  opts.on("-b", "--badge", "Rebuild badge counter for recently attributed records") do
    options[:badge] = true
  end

  opts.on("-v", "--verify", "Verify that dataset record counts are less than or equal to current count on GBIF") do
    options[:verify] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

datasets = Bionomia::GbifDataset.new

if options[:badge]
  ago = DateTime.now - 1.day
  puts "Looking for recently attributed datasets...".yellow
  datasetkeys = Occurrence.joins(:user_occurrences)
                          .where("user_occurrences.created >= '#{ago}'")
                          .pluck(:datasetKey)
                          .flatten
                          .uniq
  Dataset.where(uuid: datasetkeys).find_each do |d|
    d.refresh_search
    puts d.uuid.green
  end
  puts "Done!".green
end

if options[:populate]
  keys = Occurrence.select(:datasetKey).distinct.pluck(:datasetKey).compact
  Dataset.import keys.map{|k| { datasetKey: k }}, batch_size: 1_000, on_duplicate_key_ignore: true, validate: false
  datasets.update_all
elsif options[:all]
  datasets.update_all
elsif options[:new]
  occurrence_keys = Occurrence.select(:datasetKey).distinct.pluck(:datasetKey).compact
  dataset_keys = Dataset.select(:datasetKey).distinct.pluck(:datasetKey)
  (occurrence_keys - dataset_keys).each do |d|
    datasets.process_dataset(d)
    puts d.green
  end
elsif options[:flush]
  occurrence_keys = Occurrence.select(:datasetKey).distinct.pluck(:datasetKey).compact
  dataset_keys = Dataset.select(:datasetKey).distinct.pluck(:datasetKey)
  (dataset_keys - occurrence_keys).each do |d|
    Dataset.find_by_uuid(d).destroy
    puts d.red
  end
elsif options[:datasetkey]
  datasets.process_dataset(options[:datasetkey])
elsif options[:remove]
  Dataset.find_each do |d|
    next if d.has_agent?
    puts d.uuid.red
    d.destroy
  end
elsif options[:verify]
  Dataset.where("occurrences_count > 1000").where(dataset_type: "OCCURRENCE").find_each do |d|
    if d.current_occurrences_count < d.occurrences_count
      puts d.uuid.red
    else
      puts d.uuid.green
    end
  end
end

if options[:counter]
  puts "Updating occurrence counts...".yellow
  Dataset.update_all(occurrences_count: 0, source_attribution_count: 0)
  Parallel.each(Dataset.find_in_batches(batch_size: 250), progress: "Rebuilding dataset counters", in_threads: 3) do |batch|
    ids = batch.map(&:id)
    Occurrence.counter_culture_fix_counts only: :dataset, start: ids.min, finish: ids.max
    Dataset.joins(:user_occurrences)
           .where(user_occurrences: { created_by: User::GBIF_AGENT_ID })
           .where(id: ids.min..ids.max)
           .group(:id)
           .count
           .each do |k,v|
      d = Dataset.find(k)
      d.skip_callbacks = true
      d.source_attribution_count = v
      d.save
    end
  end
  puts "Counters rebuilt".green
end