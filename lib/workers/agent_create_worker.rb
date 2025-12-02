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

        # Create an unparsed agent if it has all nil keys
        if agent.symbolize_keys == DwcAgent.default.to_h
          agent = Agent.create_or_find_by({
            family: "",
            given: "",
            unparsed: agent_job.agents.truncate(150).strip
          })
          import(agent_id: agent.id, row: agent_job)
          next
        end

        family = agent["family"].to_s.squeeze(" ").strip
        given = agent["given"].to_s.squeeze(" ").strip
        particle = agent["particle"].to_s.squeeze(" ").strip
        appellation = agent["appellation"].to_s.squeeze(" ").strip
        title = agent["title"].to_s.squeeze(" ").strip
        suffix = agent["suffix"].to_s.squeeze(" ").strip
        nick = agent["nick"].to_s.squeeze(" ").strip
        dropping_particle = agent["dropping_particle"].to_s.squeeze(" ").strip

        family_part = [particle, family].compact.join(' ')
        given_part = [given, dropping_particle].compact.join(' ')
        display_order = [given_part, family_part, suffix].compact.reject(&:empty?).join(' ')

        # Create an unparsed agent if it's missing features
        if missing_features(agent: agent)
          agent = Agent.create_or_find_by({
            family: "",
            given: "",
            unparsed: display_order.truncate(150)
          })
          import(agent_id: agent.id, row: agent_job)
          next
        end

        # Create an agent
        # Why does this appear to fail here?
        agent = Agent.create_or_find_by({
          family: family.truncate(50),
          given: given.truncate(50),
          particle: particle.truncate(25),
          appellation: appellation.truncate(25),
          title: title.truncate(25),
          suffix: suffix.truncate(25),
          nick: nick.truncate(25),
          dropping_particle: dropping_particle.truncate(25), 
          unparsed: ""
        })
        import(agent_id: agent.id, row: agent_job)
      end

    end

    def missing_features(agent:)
      return true if agent["family"].blank?
      return true if agent["family"].length > 40
      return true if agent["family"].count(".") > 4
      return true if agent["given"] && agent["given"].length > 40
      return true if agent["given"] && agent["given"].count(".") > 5
      return false
    end

    def import(agent_id:, row:)
      slice = 1_000
      cols = [:occurrence_id, :agent_id, :agent_role]
      row.gbifIDs_recordedBy
         .tr('[]', '')
         .split(',')
         .each_slice(slice) do |group|
            OccurrenceAgent.import cols,
                                   group.map(&:to_i).zip([agent_id]*slice, [true]*slice), 
                                   validate: false, 
                                   on_duplicate_key_ignore: true
         end
      row.gbifIDs_identifiedBy
         .tr('[]', '')
         .split(',')
         .each_slice(slice) do |group|
            OccurrenceAgent.import cols, 
                                   group.map(&:to_i).zip([agent_id]*slice, [false]*slice), 
                                   validate: false, 
                                   on_duplicate_key_ignore: true
         end
    end

  end
end
