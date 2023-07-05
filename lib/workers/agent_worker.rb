# encoding: utf-8

module Bionomia
  class AgentWorker
    include Sidekiq::Job
    sidekiq_options queue: :agent, retry: 3

    def perform(row)
      data = JSON.parse(row, symbolize_names: true)
      agents = DwcAgent.parse(data[:agents])
                       .map{|a| DwcAgent.clean(a)}
                       .compact
                       .uniq
      agents.each do |a|
        next if !a.family || a.family.length < 2

        family = [a.particle.to_s.strip, a.family.to_s.strip].join(" ")
                                                             .squeeze(" ")
                                                             .strip
        given = a.given.to_s.squeeze(" ").strip
        agent = Agent.create_or_find_by({
          family: family,
          given: given
        })
        data[:gbifIDs_recordedBy]
          .tr('[]', '')
          .split(',')
          .in_groups_of(1000, false) do |group|
            import = group.map{|r| [ r.to_i, agent.id ] }
            OccurrenceRecorder.import [:occurrence_id, :agent_id], import, batch_size: 1000, validate: false, on_duplicate_key_ignore: true
          end
        data[:gbifIDs_identifiedBy]
          .tr('[]', '')
          .split(',')
          .in_groups_of(1000, false) do |group|
            import = group.map{|r| [ r.to_i, agent.id ] }
            OccurrenceDeterminer.import [:occurrence_id, :agent_id], import, batch_size: 1000, validate: false, on_duplicate_key_ignore: true
          end
      end
    end

  end
end
