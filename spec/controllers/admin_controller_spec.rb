describe "Bionomia Administration Controller" do
  before(:each) do
    @user = User.create!({ given: "John", family: "Smith", other_names: "Jack", is_admin: true })
    env 'rack.session', csrf: 'token', omniauth: OpenStruct.new({ id: @user.id })
  end

  after(:each) do
    @user.destroy
  end

  it "should allow access to the admin welcome page" do
    get '/admin'
    expect(last_response).to be_ok
  end

end
