describe "TaxonOccurrence model" do

  it "is not valid without a taxon_id" do
    to = TaxonOccurrence.new(taxon_id: nil, occurrence_id: 1)
    expect(to).to_not be_valid
  end

  it "is not valid without an occurrence_id" do
    to = TaxonOccurrence.new(taxon_id: 1, occurrence_id: nil)
    expect(to).to_not be_valid
  end

  it "is valid with a taxon_id and an occurrence_id" do
    to = TaxonOccurrence.new(taxon_id: 1, occurrence_id: 1)
    expect(to).to be_valid
  end

end