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
  Sidekiq::Stats.new.reset
  puts "Done!".green
end

if options[:add]
  puts "Building occurrence_counts content...".yellow
  limit = 50000
  max_occurrence_id = OccurrenceAgent.maximum(:occurrence_id)

  #Over-estimate number of queries to execute, but break out when actual limit reached
  (max_occurrence_id/limit).times do |i|
    counter = OccurrenceCount.maximum(:occurrence_id) || 0
    break if counter >= max_occurrence_id
    sql = "INSERT INTO occurrence_counts (occurrence_id, agent_count, user_count)
           SELECT
            r.occurrence_id,
            count(DISTINCT r.agent_id) as agent_count,
            count(DISTINCT u.user_id) as user_count
           FROM
            user_occurrences u
          CROSS JOIN
            occurrence_agents r
          WHERE
            r.occurrence_id = u.occurrence_id
          AND
            r.agent_role = true
          AND
            u.action IN ('recorded', 'recorded,identified', 'identified,recorded')
          AND
            r.occurrence_id > #{counter}
          GROUP BY
            u.occurrence_id
          HAVING agent_count > 2 AND agent_count <> user_count
          LIMIT #{limit}"
    ActiveRecord::Base.connection.execute(sql)
    break if counter == OccurrenceCount.maximum(:occurrence_id)
  end
  puts "Done!".green
end

if options[:jobs]
  puts "Creating jobs for the queue...".yellow
  group = []
  OccurrenceCount.find_each do |o|
    group << [{ id: o.id }.stringify_keys]
    next if o.id % 1000 != 0
    Sidekiq::Client.push_bulk({ 'class' => Bionomia::OccurrenceCountWorker, 'args' => group })
    puts o.id.to_s.green
    group = []
  end
  if group.size > 0
    Sidekiq::Client.push_bulk({ 'class' => Bionomia::OccurrenceCountWorker, 'args' => group })
  end
  puts "Done!".green
end
