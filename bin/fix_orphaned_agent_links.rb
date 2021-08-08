#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: fix_orphaned_agent_links.rb [options]. Fixes creation of orphaned entries in occurrence_recorders and occurrence_determiners"

  opts.on("-f", "--file [FILE]", String, "Import attributions using a csv file whose first column is an ORCID or wikidata identifier") do |file|
    options[:file] = file
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:file]
  mime_type = `file --mime -b "#{options[:file]}"`.chomp
  raise RuntimeError, 'File must be a csv' if !mime_type.include?("text/plain") && !mime_type.include?("application/csv")

  agent_ids = {}
  CSV.foreach(options[:file]) do |row|
    fullname = [row[2], row[1]].compact.reject(&:empty?).join(" ").strip
    if !agent_ids.key?(fullname)
      agent_ids[fullname] = { ids: [], family: row[1], given: row[2] }
      agent_ids[fullname][:ids] << row[0].to_i
    else
      agent_ids[fullname][:ids] << row[0].to_i
    end
  end

  agent_ids.each do |k,v|
    agent = Agent.where(family: v[:family], given: v[:given]).first
    if v[:ids].include?(agent.id)
      v[:ids].delete(agent.id)
      OccurrenceRecorder.where(agent_id: v[:ids]).find_each do |o|
        begin
          old_id = o.agent_id.dup
          o.agent_id = agent.id
          o.save
        rescue
          puts "old_agent:#{old_id}, new_agent:#{agent.id}, occurrence_recorders.occurrence_id:#{o.occurrence_id}".red
          o.destroy
          next
        end
      end
      OccurrenceDeterminer.where(agent_id: v[:ids]).find_each do |o|
        begin
          old_id = o.agent_id.dup
          o.agent_id = agent.id
          o.save
        rescue
          puts "old_agent:#{old_id}, new_agent:#{agent.id}, occurrence_determiners.occurrence_id:#{o.occurrence_id}".red
          o.destroy
          next
        end
      end
    else
      puts "identifier missing for #{k}".red
    end
  end

end
