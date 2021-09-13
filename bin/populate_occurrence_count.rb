#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: populate_occurrence_count.rb [options]"

  opts.on("-t", "--truncate", "Truncate data") do |a|
    options[:truncate] = true
  end

  opts.on("-a", "--add", "Add agent and user counts") do |a|
    options[:add] = true
  end

  opts.on("-j", "--jobs", "Create jobs for the processing queue") do |j|
    options[:jobs] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:truncate]
  puts "Truncating table...".yellow
  Occurrence.connection.execute("TRUNCATE TABLE occurrence_counts")
  redis = Redis.new(url: ENV['REDIS_URL'])
  redis.flushdb
  Sidekiq::Stats.new.reset
  puts "Done!".green
end

if options[:add]
  puts "Building occurrence_counts content...".yellow
  sql = "INSERT INTO occurrence_counts (occurrence_id, agent_count, user_count)
         SELECT DISTINCT a.occurrence_id, a.agent_count, b.user_count FROM
         (SELECT r.occurrence_id, count(r.agent_id) as agent_count FROM `occurrence_recorders` r group by r.occurrence_id having count(r.agent_id) > 1) a JOIN
         (SELECT u.occurrence_id, count(u.user_id) as user_count FROM user_occurrences u where u.action IN ('recorded', 'recorded,identified', 'identified,recorded') group by u.occurrence_id) b ON a.occurrence_id = b.occurrence_id
         WHERE a.agent_count > b.user_count"
  ActiveRecord::Base.connection.execute(sql)
  puts "Done!".green
end

if options[:jobs]
  puts "Creating jobs for the queue...".yellow
  group = []
  OccurrenceCount.find_each do |o|
    group << [{ "id" => o.id }]
    next if o.id % 1000 != 0
    Sidekiq::Client.push_bulk({ 'class' => Bionomia::OccurrenceCountWorker, 'args' => group })
    puts o.id.to_s.green
    group = []
  end
  puts "Done!".green
end
