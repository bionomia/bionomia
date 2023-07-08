#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: frictionless_dataset.rb [options]. Create frictionless datasets."

  opts.on("-k", "--key [key]", String, "Create a datataset from a specific uuid") do |key|
    options[:key] = key
  end

  opts.on("-d", "--directory [directory]", String, "Directory to create zipped frictionless data package") do |directory|
    options[:directory] = directory
  end

  opts.on("-a", "--all", "Queue all data packages for all datasets that have at least one public claim") do
    options[:all] = true
  end

  opts.on("-s","--skip", "Skip large data sets") do
    options[:skip] = true
  end

  opts.on("-l", "--list x,y,z", Array, "Queue dataset keys to update") do |list|
    options[:list] = list
  end

  opts.on("-m", "--missing", "Limit creation of datasets to those that do not yet exist") do
    options[:missing] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:directory] && options[:key]
  dataset = Dataset.find_by_uuid(options[:key]) rescue nil
  return if dataset.nil?
  begin
    puts "Starting #{dataset.title}...".yellow
    f = Bionomia::FrictionlessGenerator.new(dataset: dataset, output_directory: options[:directory])
    f.create
  rescue
    puts "Package failed for #{dataset.uuid}".red
  end
elsif options[:directory] && ( options[:all] || options[:missing] )
  group = []
  Dataset.find_each.with_index do |dataset, i|
    next if !dataset.has_claim?
    next if options[:skip] && dataset.is_large?
    next if i % 100 != 0
    group << [{ uuid: dataset.uuid, output_directory: options[:directory] }.stringify_keys]
    Sidekiq::Client.push_bulk({ 'class' => Bionomia::FrictionlessWorker, 'args' => group })
    group = []
  end
  if group.size > 0
    Sidekiq::Client.push_bulk({ 'class' => Bionomia::FrictionlessWorker, 'args' => group })
  end
elsif options[:directory] && options[:list]
  options[:list].each do |key|
    dataset = Dataset.find_by_uuid(key) rescue nil
    next if dataset.nil?
    row = { uuid: dataset.uuid, output_directory: options[:directory] }.stringify_keys
    ::Bionomia::FrictionlessWorker.perform_async(row)
  end
end
