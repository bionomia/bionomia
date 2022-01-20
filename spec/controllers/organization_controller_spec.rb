describe "Bionomia Organization Controller" do

  before(:each) do
    @wikidata = "Q12345"
    @organization = Organization.new({ name: "My Museum", wikidata: @wikidata })
    @organization.skip_callbacks = true
    @organization.save
  end

  after(:each) do
    @organization.destroy
  end

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

  it "should allow accessing an organization page" do
    get '/organization/' + @wikidata
    expect(last_response).to be_ok
  end

  it "should allow accessing an organization past members page" do
    get '/organization/' + @wikidata + '/past'
    expect(last_response).to be_ok
  end

  it "should allow accessing an organization metrics page" do
    get '/organization/' + @wikidata + '/metrics'
    expect(last_response).to be_ok
  end

  it "should allow accessing an organization citations page" do
    get '/organization/' + @wikidata + '/citations'
    expect(last_response).to be_ok
  end

end
