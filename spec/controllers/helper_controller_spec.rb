describe "Bionomia Helper Controller" do
  before(:each) do
    User.skip_callback(:before, :after)
    @user = User.create({ given: "John", family: "Smith", other_names: "Jack" })
    env 'rack.session', csrf: 'token', omniauth: OpenStruct.new({ id: @user.id })
  end

  after(:each) do
    @user.delete
  end

  it "should allow access to the help-others page" do
    get '/help-others'
    expect(last_response).to be_ok
  end

  it "should allow access to the help-others/progress page" do
    get '/help-others/progress'
    expect(last_response).to be_ok
  end

  it "should allow access to the help-others/progress/wikidata page" do
    get '/help-others/progress/wikidata'
    expect(last_response).to be_ok
  end

  it "should allow access to the help-others/add page" do
    get '/help-others/add'
    expect(last_response).to be_ok
  end

  it "should allow access to the help-others/new-people page" do
    get '/help-others/new-people'
    expect(last_response).to be_ok
  end

  it "should allow access to the help-others/new-people/wikidata page" do
    get '/help-others/new-people/wikidata'
    expect(last_response).to be_ok
  end

  it "should allow access to the help-others/country/CA page" do
    get '/help-others/country/CA'
    expect(last_response).to be_ok
  end

end
