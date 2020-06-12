describe "Taxon model" do

  it "is not valid without a family" do
    t = Taxon.new(family: nil)
    expect(t).to_not be_valid
  end

  it "is valid with a family name" do
    t = Taxon.new(family: "Lycosidae")
    expect(t).to be_valid
  end

end