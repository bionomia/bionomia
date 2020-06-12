#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: cluster_agents.rb [options]"

  opts.on("-c", "--cluster", "Cluster agents by family name") do
    options[:cluster] = true
  end

  opts.on("-t", "--truncate", "Delete all nodes and relationships from Neo4j") do
    options[:truncate] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:truncate]
  Neo4j::ActiveBase.current_session.query('MATCH (n) DETACH DELETE n')
  Sidekiq::Stats.new.reset
end

if options[:cluster]
  write_graphics = options[:write] ? true : false
  duplicates = Agent.where("family NOT LIKE '%.%'")
                    .where.not(given: ["", nil])
                    .group("family, LOWER(LEFT(given,1))")
                    .having('count(*) > 1')
                    .pluck("ANY_VALUE(id)")
                    .uniq
  duplicates.in_groups_of(1000, false) do |group|
    Sidekiq::Client.push_bulk({ 'class' => Bionomia::ClusterWorker, 'args' => group.map{ |i| [i] } })
  end

end
