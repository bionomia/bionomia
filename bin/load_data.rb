#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'
require 'zlib'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: load_data.rb [options]"

  opts.on("-d", "--directory [directory]", String, "Directory to load csv file(s)") do |directory|
    options[:directory] = directory
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:directory]
  directory = options[:directory]
  raise "Directory not found" unless File.directory?(directory)

  # NOTE: requires settings in my.cnf to permit this AND \N used as values to indicate NULL
  csv_files_in_dir = Dir.glob("#{directory}/*.csv")
  Parallel.each(csv_files_in_dir, progress: "Load csv files", in_threads: 4) do |file|
    ActiveRecord::Base.connection.execute("LOAD DATA INFILE '#{file}' INTO TABLE occurrences FIELDS TERMINATED by ',' ENCLOSED BY '\"' LINES TERMINATED BY '\\n'")
  end

end
