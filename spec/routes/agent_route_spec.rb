describe "Bionomia Agent Route" do

#  it "should allow accessing the agents page" do
#    get '/agents'
#    expect(last_response).to be_ok
#  end

  it "should allow accessing the agents gbifID" do
    get '/agents/gbifID'
    expect(last_response).to be_ok
  end

  it "should allow accessing the agent json search" do
    get '/agent.json'
    expect(last_response).to be_ok
  end
end
