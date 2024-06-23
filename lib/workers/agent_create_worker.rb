# encoding: utf-8

module Bionomia
  class AgentCreateWorker
    include Sidekiq::Job
    sidekiq_options queue: :default, retry: 3

    def perform(row)
      agent_job = AgentJob.find(row["id"]) rescue nil
      return if agent_job.nil?

      if !agent_job.parsed
        agent = Agent.create_or_find_by({
          family: "",
          given: "",
          unparsed: agent_job.agents.truncate(150).strip
        })
        import(agent_id: agent.id, row: agent_job)
        return
      end

      agent_job.parsed.each do |agent|
        family = [agent["particle"].to_s.strip, agent["family"].to_s.strip].join(" ")
                    .squeeze(" ")
                    .strip
        given = agent["given"].to_s.squeeze(" ").strip

        if missing_features(agent: agent)
          agent = Agent.create_or_find_by({
            family: "",
            given: "",
            unparsed: [given, family].join(" ").truncate(150).strip
          })
          import(agent_id: agent.id, row: agent_job)
          next
        end

        agent = Agent.create_or_find_by({
          family: family.truncate(40),
          given: given,
          unparsed: ""
        })
        import(agent_id: agent.id, row: agent_job)
      end

    end

    def missing_features(agent:)
      return true if !agent["family"]
      return true if agent["family"].length > 40
      return true if agent["family"].count(".") > 4
      return true if agent["given"] && agent["given"].length > 40
      return true if agent["given"] && agent["given"].count(".") > 5
      return false
    end

    def import(agent_id:, row:)
      row.gbifIDs_recordedBy
         .tr('[]', '')
         .split(',')
         .each_slice(1_000) do |group|
            import = group.map{|r| [ r.to_i, agent_id, true ] }
            OccurrenceAgent.import [:occurrence_id, :agent_id, :agent_role], import, validate: false, on_duplicate_key_ignore: true
         end
      row.gbifIDs_identifiedBy
         .tr('[]', '')
         .split(',')
         .each_slice(1_000) do |group|
            import = group.map{|r| [ r.to_i, agent_id, false ] }
            OccurrenceAgent.import [:occurrence_id, :agent_id, :agent_role], import, validate: false, on_duplicate_key_ignore: true
         end
    end

  end
end
