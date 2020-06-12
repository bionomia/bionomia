class ForceCreateAgentNodeUuidConstraint < Neo4j::Migrations::Base
  def up
    add_constraint :AgentNode, :uuid, force: true
  end

  def down
    drop_constraint :AgentNode, :uuid
  end
end
