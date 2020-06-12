# encoding: utf-8

module Bionomia
  class ClusterWorker
    include Sidekiq::Worker
    sidekiq_options queue: :cluster

    def perform(id)
      @agent = Agent.find(id)
      add_edges
    end

    def add_edges
      nodes = []
      agents = @agent.agents_same_family_first_initial
      agents.find_each do |a|
        nodes << AgentNode.create({
          agent_id: a.id,
          family: a.family,
          given: a.given })
      end
      begin
        retries ||= 0
        nodes.combination(2).each do |pair|
          w = DwcAgent.similarity_score(pair.first.given, pair.second.given)
          if w > 0
            AgentEdge.create(
              from_node: pair.first,
              to_node: pair.second, weight: w)
          end
        end
      rescue
        retry if (retries += 1) < 3
      end

    end

  end
end
