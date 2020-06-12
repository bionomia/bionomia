# encoding: utf-8

module Bionomia
  class AgentWorker
    include Sidekiq::Worker
    sidekiq_options queue: :agent

    def perform(row)
      agents = parse(row["agents"])
      agents.each do |a|
        agent = Agent.create_or_find_by({
          family: a[:family].to_s.strip,
          given: a[:given].to_s.strip
        })
        recs = row["gbifIDs_recordedBy"]
                  .tr('[]', '')
                  .split(',')
                  .map{|r| [ r.to_i, agent.id ] }
        ids = row["gbifIDs_identifiedBy"]
                  .tr('[]', '')
                  .split(',')
                  .map{|r| [ r.to_i, agent.id ] }
        if !recs.empty?
          OccurrenceRecorder.import [:occurrence_id, :agent_id], recs, batch_size: 2500, validate: false, on_duplicate_key_ignore: true
        end
        if !ids.empty?
          OccurrenceDeterminer.import [:occurrence_id, :agent_id], ids, batch_size: 2500, validate: false, on_duplicate_key_ignore: true
        end
      end
    end

    def parse(raw)
      agents = []
      DwcAgent.parse(raw).each do |n|
        agent = DwcAgent.clean(n)
        if !agent[:family].nil? && agent[:family].length >= 2
          agents << agent
        end
      end
      agents.uniq
    end

  end
end
