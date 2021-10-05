# encoding: utf-8

module Bionomia
  class AgentWorker
    include Sidekiq::Worker
    sidekiq_options queue: :agent

    def perform(row)
      agents = parse(row["agents"])
      agents.each do |a|
        family = [a.particle.to_s.strip, a.family.to_s.strip].join(" ")
        agent = Agent.create_or_find_by({
          family: family,
          given: a.given.to_s.strip
        })
        row["gbifIDs_recordedBy"]
          .tr('[]', '')
          .split(',')
          .in_groups_of(1000, false) do |group|
            import = group.map{|r| [ r.to_i, agent.id ] }
            OccurrenceRecorder.import [:occurrence_id, :agent_id], import, batch_size: 1000, validate: false, on_duplicate_key_ignore: true
          end
        row["gbifIDs_identifiedBy"]
          .tr('[]', '')
          .split(',')
          .in_groups_of(1000, false) do |group|
            import = group.map{|r| [ r.to_i, agent.id ] }
            OccurrenceDeterminer.import [:occurrence_id, :agent_id], import, batch_size: 1000, validate: false, on_duplicate_key_ignore: true
          end
      end
    end

    def parse(raw)
      agents = []
      DwcAgent.parse(raw).each do |n|
        agent = DwcAgent.clean(n)
        if !agent.family.nil? && agent.family.length >= 2
          agents << agent
        end
      end
      agents.uniq
    end

  end
end
