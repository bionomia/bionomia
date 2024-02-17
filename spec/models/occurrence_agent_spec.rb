describe "OccurrenceAgent model" do

  it "is not valid without an agent_id" do
    od = OccurrenceAgent.new(agent_id: nil, occurrence_id: 1)
    expect(od).to_not be_valid
  end

  it "is not valid without an occurrence_id" do
    od = OccurrenceAgent.new(agent_id: 1, occurrence_id: nil)
    expect(od).to_not be_valid
  end

  it "is valid with a default agent_role" do
    od = OccurrenceAgent.new(agent_id: 1, occurrence_id: 1)
    expect(od).to be_valid
  end

  it "is valid" do
    od = OccurrenceAgent.new(agent_id: 1, occurrence_id: 1, agent_role: true)
    expect(od).to be_valid
  end

end