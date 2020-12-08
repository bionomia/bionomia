describe "TaxonImage model" do

  it "is not valid without a family" do
    to = TaxonImage.new(family: nil, file_name: "image.png")
    expect(to).to_not be_valid
  end

  it "is not valid without a file_name" do
    to = TaxonImage.new(family: "Linyphiidae", file_name: nil)
    expect(to).to_not be_valid
  end

  it "is valid with a family and a file_name" do
    to = TaxonImage.new(family: "Linyphiidae", file_name: "image.png")
    expect(to).to be_valid
  end

end
