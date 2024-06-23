describe "Agent model" do

  it "is not valid without given content" do
    agent = Agent.new(given: nil, family: "", parsed: "")
    expect(agent).to_not be_valid
  end

  it "is not valid without family content" do
    agent = Agent.new(given: "", family: nil, parsed: "")
    expect(agent).to_not be_valid
  end

  it "is not valid without parsed content" do
    agent = Agent.new(given: "", family: "", parsed: nil)
    expect(agent).to_not be_valid
  end

end