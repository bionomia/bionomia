#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: frictionless_dataset.rb [options]. Create frictionless datasets."

  opts.on("-k", "--key [key]", String, "Create a datataset from a specific key") do |key|
    options[:key] = key
  end

  opts.on("-d", "--directory [directory]", String, "Directory to create zipped frictionless data package") do |directory|
    options[:directory] = directory
  end

  opts.on("-a", "--all", "Make data packages for all datasets that have at least one public claim") do
    options[:all] = true
  end

  opts.on("-s","--skip", "Skip large data sets") do
    options[:skip] = true
  end

  opts.on("-l", "--list x,y,z", Array, "List of dataset keys to update") do |list|
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
  if dataset
    begin
      puts "Starting #{dataset.title}...".yellow
      f = Bionomia::FrictionlessGenerator.new(dataset: dataset, output_directory: options[:directory])
      f.create
    rescue
      puts "Package failed for #{dataset.datasetKey}".red
    end
  else
    puts "Package #{options[:key]} not found".red
  end
elsif options[:directory] && ( options[:all] || options[:missing] )
  Dataset.find_each do |d|
    next if !d.has_claim?
    next if options[:skip] && d.is_large?
    puts "Starting #{d.title}...".yellow
    begin
      f = Bionomia::FrictionlessGenerator.new(dataset: d, output_directory: options[:directory])
      f.create
    rescue
      puts "Package failed for #{d.datasetKey}".red
    end
  end
elsif options[:directory] && options[:list]
  options[:list].each do |key|
    dataset = Dataset.find_by_datasetKey(key) rescue nil
    if dataset
      puts "Starting #{dataset.title}...".yellow
      begin
        f = Bionomia::FrictionlessGenerator.new(dataset: d, output_directory: options[:directory])
        f.create
      rescue
        puts "Package failed for #{d.datasetKey}".red
      end
    else
      puts "Package #{key} not found".red
    end
  end
end
