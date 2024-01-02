describe "Bionomia User Route" do
  before(:each) do
    @user = User.new({ given: "John", family: "Smith", other_names: "Jack", is_public: true })
    @user.skip_callbacks = true
    @user.save
    @user.update_columns({ orcid: "0000-0001-7618-5230" })
    env 'rack.session', csrf: 'token', omniauth: OpenStruct.new({ id: @user.id })
  end

  after(:each) do
    @user.delete
  end

  it "should get the user overview page" do
    get '/' + @user.identifier
    expect(last_response).to be_ok
  end

  it "should get the user specialties page" do
    get '/' + @user.identifier + '/specialties'
    expect(last_response).to be_ok
  end

  it "should get the user co-collectors page" do
    get '/' + @user.identifier + '/co-collectors'
    expect(last_response).to be_ok
  end

  it "should get the user identified-for page" do
    get '/' + @user.identifier + '/identified-for'
    expect(last_response).to be_ok
  end

  it "should get the user identifications-by page" do
    get '/' + @user.identifier + '/identifications-by'
    expect(last_response).to be_ok
  end

  it "should get the user deposited-at page" do
    get '/' + @user.identifier + '/deposited-at'
    expect(last_response).to be_ok
  end

  it "should get the user specimens page" do
    get '/' + @user.identifier + '/specimens'
    expect(last_response).to be_ok
  end

  it "should get the user collector strings page" do
    get '/' + @user.identifier + '/strings'
    expect(last_response).to be_ok
  end

  it "should get the user helped-by page" do
    get '/' + @user.identifier + '/support'
    expect(last_response).to be_ok
  end

  it "should get the user science endabled page" do
    get '/' + @user.identifier + '/citations'
    expect(last_response).to be_ok
  end

  it "should get the user helped page" do
    get '/' + @user.identifier + '/helped'
    expect(last_response).to be_ok
  end

  it "should allow accessing the about user rss feed" do
    get '/user.rss'
    expect(last_response).to be_ok
  end

  it "should allow accessing the user json search" do
    get '/user.json'
    expect(last_response).to be_ok
  end

end
