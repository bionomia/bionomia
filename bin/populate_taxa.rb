#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: populate_taxa.rb [options]"

  opts.on("-t", "--truncate", "Truncate data") do
    options[:truncate] = true
  end

  opts.on("-d", "--directory [directory]", String, "Directory containing csv file(s)") do |directory|
    options[:directory] = directory
  end

  opts.on("-p", "--phylopic", "Add any new silhouettes from Phylopic") do
    options[:phylopic] = true
  end

  opts.on("-f", "--family [family]", String, "Limit adding new pic from Phylopic to a Family") do |family|
    options[:family] = family
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:truncate]
  tables = [
    "taxa",
    "taxon_occurrences"
  ]
  tables.each do |table|
    Occurrence.connection.execute("TRUNCATE TABLE #{table}")
  end
  redis = Redis.new(url: ENV['REDIS_URL'])
  redis.flushdb
  Sidekiq::Stats.new.reset
end

if options[:directory]
  directory = options[:directory]
  raise "Directory not found" unless File.directory?(directory)
  accepted_formats = [".csv"]
  files = Dir.entries(directory).select {|f| accepted_formats.include?(File.extname(f))}

  files.each do |file|
    file_path = File.join(options[:directory], file)
    CSV.foreach(file_path, headers: true) do |row|
      groups = []
      row["gbifIDs_family"].tr('[]', '')
                          .split(",")
                          .in_groups_of(1000, false) do |group|
        groups << [{ family: row["family"], gbifIDs_family: group.map(&:to_i) }]
      end
      Sidekiq::Client.push_bulk({ 'class' => Bionomia::TaxonWorker, 'args' => groups })
    end
    puts file.green
  end
end

if options[:phylopic]
  if options[:family]
    TaxonImage.phylopic_search(options[:family])
  else
    TaxonImage.phylopic_search_all
  end
end
