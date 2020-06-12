class AgentEdge
  include Neo4j::ActiveRel
  from_class :AgentNode
  to_class   :AgentNode

  property :weight, type: Float
end