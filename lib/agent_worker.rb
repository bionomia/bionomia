# encoding: utf-8

module Bionomia
  class AgentWorker
    include Sidekiq::Worker
    sidekiq_options queue: :agent

    def perform(row)
      agents = parse(row["agents"])
      recorded_by = row["gbifIDs_recordedBy"].tr('[]', '').split(',')
      identified_by = row["gbifIDs_identifiedBy"].tr('[]', '').split(',')

      agents_csv = CSV.open("agents.csv", "a+")
      file_id = rand(1..50)
      occurrence_recorders_csv = CSV.open("occurrence_recorders_files/occurrence_recorders_#{file_id}.csv", "a+")
      occurrence_determiners_csv = CSV.open("occurrence_determiners_files/occurrence_determiners_#{file_id}.csv", "a+")

      Sidekiq.redis do |conn|
        agents.each do |a|
          given = a.given.to_s.strip
          family = a.family.to_s.strip
          name = [given,family].join("-")

          id = conn.get("agent:#{name}")
          if !id
            id = conn.incr("agent:key")
            conn.set("agent:#{name}", id)
            agents_csv << [id, family, given]
          end
          recorded_by.in_groups_of(1000, false) do |group|
            group.each do |row|
              occurrence_recorders_csv << [ row, id ]
            end
          end
          identified_by.in_groups_of(1000, false) do |group|
            group.each do |row|
              occurrence_determiners_csv << [ row, id ]
            end
          end

        end
      end

      agents_csv.close
      occurrence_recorders_csv.close
      occurrence_determiners_csv.close
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
