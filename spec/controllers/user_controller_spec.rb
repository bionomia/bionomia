describe "Bionomia User Controller" do

  before(:each) do
    env 'rack.session', csrf: 'token'
  end

  it "sets the env to be sent with requests" do
    get '/profile'
    expect(last_request.env['rack.session']['csrf']).to eq('token')
  end

  it 'persists across multiple requests' do
    request '/profile'
    request '/profile'

    expect(last_request.env['rack.session']['csrf']).to eq('token')
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
