#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

INDICES = ["agent", "article", "dataset", "organization", "user", "taxon"]

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: populate_search.rb [options]"

  opts.on("-r", "--rebuild", "Rebuild the index") do |a|
    options[:rebuild] = true
  end

  opts.on("-i", "--index [directory]", String, "Rebuild a particular index. Acccepted are #{INDICES.join(", ")}") do |index|
    options[:index] = index
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:rebuild]
  INDICES.each do |index_name|
    index = Object.const_get("Bionomia::Elastic#{index_name.capitalize}").new
    index.delete_index
    index.create_index
    puts "Importing #{index_name}s..."
    index.import
    index.refresh_index
  end
end

if options[:index]
  if INDICES.include?(options[:index])
    index = Object.const_get("Bionomia::Elastic#{options[:index].capitalize}").new
    index.delete_index
    index.create_index
    puts "Importing #{options[:index]}s..."
    index.import
    index.refresh_index
  else
    puts "Accepted values are #{INDICES.join(", ")}"
  end
end
