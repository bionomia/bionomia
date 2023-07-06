#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: populate_agents.rb [options]"

  opts.on("-d", "--directory [directory]", String, "Directory containing csv file(s)") do |directory|
    options[:directory] = directory
  end

  opts.on("-t", "--truncate", "Truncate data") do |a|
    options[:truncate] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:truncate]
  tables = [
    "agents",
    "occurrence_determiners",
    "occurrence_recorders"
  ]
  tables.each do |table|
    Occurrence.connection.execute("TRUNCATE TABLE #{table}")
  end
  Sidekiq::Stats.new.reset
end

if options[:directory]
  directory = options[:directory]
  raise "Directory not found" unless File.directory?(directory)
  accepted_formats = [".csv"]
  files = Dir.entries(directory).select {|f| accepted_formats.include?(File.extname(f))}

  files.each do |file|
    file_path = File.join(options[:directory], file)
    group = []
    CSV.foreach(file_path, headers: true).with_index do |row, i|
      group << [row.to_hash]
      next if i % 100 != 0
      Sidekiq::Client.push_bulk({ 'class' => Bionomia::AgentWorker, 'args' => group })
      group = []
    end
    if group.size > 0
      Sidekiq::Client.push_bulk({ 'class' => Bionomia::AgentWorker, 'args' => group })
    end
    puts file.green
  end

end
