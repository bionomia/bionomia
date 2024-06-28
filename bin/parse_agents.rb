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
  progressbar = ProgressBar.create(title: "Agent Jobs", total: AgentJob.count)

  group = []
  AgentJob.find_each do |o|
    group << [{ id: o.id }.stringify_keys]
    next if o.id % 50_000 != 0
    Sidekiq::Client.push_bulk({ 'class' => Bionomia::AgentParseWorker, 'args' => group })
    progressbar.progress += group.size
    group = []
  end
  if group.size > 0
    Sidekiq::Client.push_bulk({ 'class' => Bionomia::AgentParseWorker, 'args' => group })
    progressbar.progress += group.size
  end
end
