describe "Bionomia Administration Route" do
  before(:each) do
    @user = User.new({ given: "John", family: "Smith", other_names: "Jack", is_admin: true })
    @user.skip_callbacks = true
    @user.save
    env 'rack.session', csrf: 'token', omniauth: OpenStruct.new({ id: @user.id })
  end

  after(:each) do
    @user.delete
  end

  it "should allow access to the admin welcome page" do
    get '/admin'
    expect(last_response).to be_ok
  end

  it "should allow access to the admin articles page" do
    get '/admin/articles'
    expect(last_response).to be_ok
  end

  it "should allow access to the admin datasets page" do
    get '/admin/datasets'
    expect(last_response).to be_ok
  end

  it "should allow access to the admin datasets search page" do
    get '/admin/datasets/search'
    expect(last_response).to be_ok
  end

  it "should allow access to the admin organizations page" do
    get '/admin/organizations'
    expect(last_response).to be_ok
  end

  it "should allow access to the admin organizations search page" do
    get '/admin/organizations/search'
    expect(last_response).to be_ok
  end

  it "should allow access to the admin taxa page" do
    get '/admin/taxa'
    expect(last_response).to be_ok
  end

  it "should allow access to the admin users page" do
    get '/admin/users'
    expect(last_response).to be_ok
  end

  it "should allow access to the admin users search page" do
    get '/admin/users/search'
    expect(last_response).to be_ok
  end

end
