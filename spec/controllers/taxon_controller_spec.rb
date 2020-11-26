describe "Bionomia Taxon Controller" do

  it "should allow accessing the countries page" do
    get '/taxa'
    expect(last_response).to be_ok
  end

  it "should allow accessing the taxon json search" do
    get '/taxon.json'
    expect(last_response).to be_ok
  end

end
