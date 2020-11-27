describe "Bionomia Dataset Controller" do
  before(:each) do
    @datasetkey = "12345"
    @dataset = Dataset.create!({ datasetKey: @datasetkey })
  end

  after(:each) do
    @dataset.destroy
  end

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

  it "should allow accessing a dataset page" do
    get '/dataset/' + @datasetkey
    expect(last_response).to be_ok
  end

  it "should allow accessing a dataset scribes page" do
    get '/dataset/' + @datasetkey + '/scribes'
    expect(last_response).to be_ok
  end

  it "should allow accessing a dataset agents page" do
    get '/dataset/' + @datasetkey + '/agents'
    expect(last_response).to be_ok
  end

  it "should allow accessing a dataset agents counts page" do
    get '/dataset/' + @datasetkey + '/agents/counts'
    expect(last_response).to be_ok
  end

  it "should allow accessing a dataset agents unclaimed page" do
    get '/dataset/' + @datasetkey + '/agents/unclaimed'
    expect(last_response).to be_ok
  end

  it "should allow accessing a dataset progress page" do
    get '/dataset/' + @datasetkey + '/progress.json'
    expect(last_response).to be_ok
  end

end
