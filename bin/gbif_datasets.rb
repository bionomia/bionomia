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

  opts.on("-v", "--verify", "Verify that dataset record counts are less than or equal to current count on GBIF") do
    options[:verify] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

datasets = Bionomia::GbifDataset.new

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
  end
elsif options[:flush]
  occurrence_keys = Occurrence.select(:datasetKey).distinct.pluck(:datasetKey).compact
  dataset_keys = Dataset.select(:datasetKey).distinct.pluck(:datasetKey)
  (dataset_keys - occurrence_keys).each do |d|
    Dataset.find_by_datasetKey(d).destroy
    puts d.red
  end
elsif options[:datasetkey]
  datasets.process_dataset(options[:datasetkey])
elsif options[:remove]
  Dataset.find_each do |d|
    next if d.has_agent?
    puts d.datasetKey.red
    d.destroy
  end
elsif options[:counter]
  Occurrence.counter_culture_fix_counts only: :dataset
  puts "Counters rebuilt".green
elsif options[:verify]
  Dataset.where("occurrences_count > 1000").find_each do |d|
    if d.current_occurrences_count < d.occurrences_count
      puts d.datasetKey.red
    else
      puts d.datasetKey.green
    end
  end
end
