describe "Bionomia Dataset Controller" do

  it "should allow accessing the datasets page" do
    get '/datasets'
    expect(last_response).to be_ok
  end

  it "should allow accessing the datasets search page" do
    get '/datasets/search'
    expect(last_response).to be_ok
  end

  it "should allow accessing the datasets json page" do
    get '/dataset.json'
    expect(last_response).to be_ok
  end

end
