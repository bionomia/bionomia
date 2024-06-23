# encoding: utf-8

module Bionomia
   class AgentParseWorker
      include Sidekiq::Job
      sidekiq_options queue: :default, retry: 3

      def perform(row)
         agent_job = AgentJob.find(row["id"]) rescue nil
         return if agent_job.nil?

         agents = DwcAgent.parse(agent_job.agents)
                       .map{|a| DwcAgent.clean(a)}
                       .compact
                       .uniq
         if !agents.empty?
            agent_job.parsed = agents
            agent_job.save
         end
      end

   end
end