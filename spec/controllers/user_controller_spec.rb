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

end
