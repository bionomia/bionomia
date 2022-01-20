describe "Dataset model" do

  it "is not valid without a datasetKey" do
    dataset = Dataset.new(datasetKey: nil)
    dataset.skip_callbacks
    expect(dataset).to_not be_valid
  end

  it "is valid with a datasetKey" do
    dataset = Dataset.new(datasetKey: "xxxxx")
    dataset.skip_callbacks
    expect(dataset).to be_valid
  end

end
