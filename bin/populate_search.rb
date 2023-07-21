#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: populate_search.rb [options]"

  opts.on("-r", "--rebuild", "Rebuild the index") do |a|
    options[:rebuild] = true
  end

  opts.on("-i", "--indices [list]", Array, "Rebuild a list of indices. Acccepted are #{INDICES.join(", ")}") do |indices|
    options[:indices] = indices
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def accepted_indices
  ["agent", "article", "dataset", "organization", "user", "taxon"]
end

if options[:rebuild]
  accepted_indices.each do |idx|
    index = Object.const_get("Bionomia::Elastic#{idx.capitalize}").new
    index.delete_index
    index.create_index
    index.refresh_index
    puts "Importing #{idx}s..."
    index.import
    index.refresh_index
  end
end

if options[:indices]
  options[:indices].each do |idx|
    if accepted_indices.include?(idx)
      index = Object.const_get("Bionomia::Elastic#{idx.capitalize}").new
      index.delete_index
      index.create_index
      index.refresh_index
      puts "Importing #{idx}s..."
      index.import
      index.refresh_index
    else
      puts "Accepted values are #{accepted_indices.join(", ")}"
    end
  end
end
