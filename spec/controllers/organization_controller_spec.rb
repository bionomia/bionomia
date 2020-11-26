describe "Bionomia Organization Controller" do

  it "should allow accessing the public list of organizations" do
    get '/organizations'
    expect(last_response).to be_ok
  end

  it "should allow accessing the public list of organizations/search" do
    get '/organizations/search'
    expect(last_response).to be_ok
  end

  it "should allow accessing the organization json search" do
    get '/organization.json'
    expect(last_response).to be_ok
  end

end
