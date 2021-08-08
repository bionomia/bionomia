describe "Bionomia Profile Controller" do
  before(:each) do
    User.skip_callback(:before, :after)
    @user = User.create({ given: "John", family: "Smith", other_names: "Jack" })
    env 'rack.session', csrf: 'token', omniauth: OpenStruct.new({ id: @user.id })
  end

  after(:each) do
    @user.delete
  end

  it "should allow access to the profile page" do
    get '/profile'
    expect(last_response).to be_ok
  end

  it 'persists across multiple requests' do
    request '/profile'
    request '/profile'

    expect(last_request.env['rack.session']['csrf']).to eq('token')
  end

  it "should allow access to the profile settings page" do
    get '/profile/settings'
    expect(last_response).to be_ok
  end

  it "should allow access to the profile specimens" do
    get '/profile/specimens'
    expect(last_response).to be_ok
  end

  it "should allow access to the profile support" do
    get '/profile/support'
    expect(last_response).to be_ok
  end

  it "should allow access to the profile helped" do
    get '/profile/helped'
    expect(last_response).to be_ok
  end

  it "should allow access to the profile messages" do
    get '/profile/messages'
    expect(last_response).to be_ok
  end

  it "should allow access to the profile upload" do
    get '/profile/upload'
    expect(last_response).to be_ok
  end

  it "should allow access to the profile ignored" do
    get '/profile/ignored'
    expect(last_response).to be_ok
  end

  it "should allow access to the profile citations" do
    get '/profile/citations'
    expect(last_response).to be_ok
  end

end
