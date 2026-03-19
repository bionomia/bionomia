#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: parse_agents.rb"

  opts.on("-q", "--queue", "Queue the jobs to parse agent strings.") do
    options[:queue] = true
  end

  opts.on("-p", "--parallel", "Parse the agent strings without a queue.") do
    options[:parallel] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:queue]
  Sidekiq::Stats.new.reset

  progressbar = ProgressBar.create(title: "Agent Jobs", total: AgentJob.count)

  (1..agent_count).each_slice(50_000) do |slice|
    group = slice.map{|a| [{ id: a }.stringify_keys]}
    Sidekiq::Client.push_bulk({ 'class' => Bionomia::AgentParseWorker, 'args' => group })
    progressbar.progress += group.size
  end
elsif options[:parallel]
  progressbar = ProgressBar.create(title: "Agent Jobs", total: AgentJob.count)

  AgentJob.in_batches(of: 5_000) do |batch|
    batch.each do |agent_job|
      next if agent_job.nil? || !agent_job.parsed.blank?

      agents = DwcAgent.parse(agent_job.agents)
                    .map{|a| DwcAgent.clean(a)}
                    .compact
                    .uniq
      next if agents.empty?
      next if agents.size == 1 && agents.first == DwcAgent.default
  
      agent_job.update_column(:parsed, agents)
    end
    progressbar.progress += batch.size
  end
end
