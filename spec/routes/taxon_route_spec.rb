describe "Bionomia Taxon Route" do
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

  it "should allow accessing a taxon agents page" do
    get '/taxon/' + @taxon.family + '/agents'
    expect(last_response.status).to eq(403)
  end

  it "should allow accessing a taxon agents counts page" do
    get '/taxon/' + @taxon.family + '/agents/counts'
    expect(last_response.status).to eq(403)
  end

  it "should allow accessing a taxon agents unclaimed page" do
    get '/taxon/' + @taxon.family + '/agents/unclaimed'
    expect(last_response.status).to eq(403)
  end

  it "should allow accessing the taxon json search" do
    get '/taxon.json'
    expect(last_response).to be_ok
  end

end
