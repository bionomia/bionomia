#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: parse_agents.rb"

  opts.on("-q", "--queue", "Queue the jobs to parse agent strings.") do
    options[:queue] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:queue]
  Sidekiq::Stats.new.reset

  agent_count = AgentJob.count
  progressbar = ProgressBar.create(title: "Agent Jobs", total: agent_count)

  (1..agent_count).each_slice(50_000) do |slice|
    group = slice.map{|a| [{ id: a }.stringify_keys]}
    Sidekiq::Client.push_bulk({ 'class' => Bionomia::AgentParseWorker, 'args' => group })
    progressbar.progress += group.size
  end
end
