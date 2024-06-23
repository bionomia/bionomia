describe "Agent model" do

  it "is not valid without given content" do
    agent = Agent.new(given: nil, family: "", unparsed: "")
    expect(agent).to_not be_valid
  end

  it "is not valid without family content" do
    agent = Agent.new(given: "", family: nil, unparsed: "")
    expect(agent).to_not be_valid
  end

  it "is not valid without unparsed content" do
    agent = Agent.new(given: "", family: "", unparsed: nil)
    expect(agent).to_not be_valid
  end

end