describe "Bionomia Taxon Controller" do
  before(:each) do
    @taxon = Taxon.create!({ family: "Linyphiidae" })
  end

  after(:each) do
    @taxon.destroy
  end

  it "should allow accessing the taxa page" do
    get '/taxa'
    expect(last_response).to be_ok
  end

  it "should allow accessing the taxon json search" do
    get '/taxon.json'
    expect(last_response).to be_ok
  end

end
