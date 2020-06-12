class AgentNode
  include Neo4j::ActiveNode
  has_many :both, :agent_nodes, rel_class: :AgentEdge

  property :agent_id, type: Integer
  property :given, type: String
  property :family, type: String

  def agent_nodes_weights
    agent_nodes(:a, :r).order_by("r.weight DESC")
                       .pluck("a.agent_id", "r.weight")
  end
end
