describe "Bionomia Country Controller" do

  it "should allow accessing the countries page" do
    get '/countries'
    expect(last_response).to be_ok
  end

  it "should allow accessing a country page" do
    get '/country/CA'
    expect(last_response).to be_ok
  end

end
