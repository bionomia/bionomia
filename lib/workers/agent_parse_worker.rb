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
         return if agents.empty?
         return if agents.size == 1 && agents.first == DwcAgent.default

         agent_job.update_column(:parsed, agents)
      end

   end
end