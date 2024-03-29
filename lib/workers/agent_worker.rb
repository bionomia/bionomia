# encoding: utf-8

module Bionomia
  class AgentWorker
    include Sidekiq::Job
    sidekiq_options queue: :default, retry: 3

    def perform(row)
      agents = DwcAgent.parse(row["agents"])
                       .map{|a| DwcAgent.clean(a)}
                       .compact
                       .uniq
      agents.each do |a|
        next if !a.family || a.family.length < 2 || a.family.length > 40

        family = [a.particle.to_s.strip, a.family.to_s.strip].join(" ")
                                                             .squeeze(" ")
                                                             .strip
        given = a.given.to_s.squeeze(" ").strip
        agent = Agent.create_or_find_by({
          family: family,
          given: given
        })
        row["gbifIDs_recordedBy"]
          .tr('[]', '')
          .split(',')
          .each_slice(2_500) do |group|
            import = group.map{|r| [ r.to_i, agent.id, true ] }
            OccurrenceAgent.import [:occurrence_id, :agent_id, :agent_role], import, validate: false, on_duplicate_key_ignore: true
          end
        row["gbifIDs_identifiedBy"]
          .tr('[]', '')
          .split(',')
          .each_slice(2_500) do |group|
            import = group.map{|r| [ r.to_i, agent.id, false ] }
            OccurrenceAgent.import [:occurrence_id, :agent_id, :agent_role], import, validate: false, on_duplicate_key_ignore: true
          end
      end
    end

  end
end
