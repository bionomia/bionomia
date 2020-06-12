describe "OccurrenceRecorder model" do

  it "is not valid without an agent_id" do
    od = OccurrenceRecorder.new(agent_id: nil, occurrence_id: 1)
    expect(od).to_not be_valid
  end

  it "is not valid without an occurrence_id" do
    od = OccurrenceRecorder.new(agent_id: 1, occurrence_id: nil)
    expect(od).to_not be_valid
  end

  it "is valid with an agent_id and an occurrence_id" do
    od = OccurrenceRecorder.new(agent_id: 1, occurrence_id: 1)
    expect(od).to be_valid
  end

end