describe "Occurrence model" do

  it "is not valid without a gbifID" do
    o = Occurrence.new(gbifID: nil)
    expect(o).to_not be_valid
  end

  it "is not valid without an id" do
    o = Occurrence.new(id: nil)
    expect(o).to_not be_valid
  end

  it "is valid with an id" do
    o = Occurrence.new(id: 1)
    expect(o).to be_valid
  end

end