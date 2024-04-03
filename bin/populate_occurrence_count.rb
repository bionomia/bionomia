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
  puts "Building occurrence_counts content from UserOccurrence...".yellow
  sql = "INSERT INTO occurrence_counts (occurrence_id, user_count)
      SELECT
        u.occurrence_id,
        COUNT(u.user_id) as user_count
      FROM
        user_occurrences u
      WHERE 
        u.action LIKE '%recorded%'
      GROUP BY
        u.occurrence_id
      HAVING count(u.user_id) > 1"
  ActiveRecord::Base.connection.execute(sql)

  puts "Refining occurrence_counts content from OccurrenceAgents..."
  OccurrenceCount.find_in_batches(batch_size: 10_000) do |group|
    ids = group.pluck(:occurrence_id).join(",")
    sql = "UPDATE 
        occurrence_counts 
      JOIN 
        (SELECT 
          occurrence_id, 
          COUNT(agent_id) AS agent_count 
        FROM 
          occurrence_agents
        WHERE 
          occurrence_id IN (#{ids}) 
        AND
          agent_role = true
        GROUP BY occurrence_id) a 
      ON 
        occurrence_counts.occurrence_id = a.occurrence_id 
      SET occurrence_counts.agent_count = a.agent_count"
      ActiveRecord::Base.connection.execute(sql)
  end

  puts "Flushing unnecessary records...".yellow
  sql = %{ DELETE FROM occurrence_counts WHERE (agent_count IN (1,2) OR agent_count IS NULL) ORDER BY id DESC LIMIT 100000 }
  total = OccurrenceCount.where(agent_count: [1,2]).or(OccurrenceCount.where(agent_count: nil)).count
  batch_total = total/100000
  (1..batch_total).each do |i|
    ActiveRecord::Base.connection.execute(sql)
    puts (batch_total - i).to_s.yellow
  end
  ActiveRecord::Base.connection.execute(sql)
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