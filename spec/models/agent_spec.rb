describe "Agent model" do

  it "is not valid without both a given and family name" do
    agent = Agent.new(given: nil, family: nil)
    expect(agent).to_not be_valid
  end

  it "is not valid without a family name" do
    agent = Agent.new(family: nil)
    expect(agent).to_not be_valid
  end

  it "is valid with a family name but not a given name" do
    agent = Agent.new(family: "Smith", given: nil)
    expect(agent).to be_valid
  end

end