describe "Bionomia Application Controller" do

  it "should allow accessing the home page" do
    get '/'
    expect(last_response).to be_ok
  end

  it "should allow accessing the public roster" do
    get '/roster'
    expect(last_response).to be_ok
  end

  it "should allow accessing the acknowledgments page" do
    get '/acknowledgments'
    expect(last_response).to be_ok
  end

  it "should allow accessing the integrations page" do
    get '/integrations'
    expect(last_response).to be_ok
  end

  it "should allow accessing the developers search page" do
    get '/developers'
    expect(last_response).to be_ok
  end

  it "should allow accessing the developers structured-data page" do
    get '/developers/structured-data'
    expect(last_response).to be_ok
  end

  it "should allow accessing the developers code page" do
    get '/developers/code'
    expect(last_response).to be_ok
  end

  it "should allow accessing the developers parse page" do
    get '/developers/parse'
    expect(last_response).to be_ok
  end

  it "should allow accessing the collection data managers page" do
    get '/collection-data-managers'
    expect(last_response).to be_ok
  end

  it "should allow accessing the donate page" do
    get '/donate'
    expect(last_response).to be_ok
  end

  it "should allow accessing the donor wall page" do
    get '/donate/wall'
    expect(last_response).to be_ok
  end

  it "should allow accessing the how it works page" do
    get '/how-it-works'
    expect(last_response).to be_ok
  end

  it "should allow accessing the about page" do
    get '/about'
    expect(last_response).to be_ok
  end

  it "should allow accessing the get-started page" do
    get '/get-started'
    expect(last_response).to be_ok
  end

  it "should allow accessing the history page" do
    get '/history'
    expect(last_response).to be_ok
  end

  it "should allow accessing the offline page" do
    get '/offline'
    expect(last_response).to be_ok
  end

  it "should allow accessing the scribes page" do
    get '/scribes'
    expect(last_response).to be_ok
  end

  it "should allow accessing the on-this-day page" do
    get '/on-this-day'
    expect(last_response).to be_ok
  end

  it "should allow accessing the on-this-day/collected page" do
    get '/on-this-day/collected'
    expect(last_response).to be_ok
  end

  it "should allow accessing the parse page" do
    get '/parse'
    expect(last_response).to be_ok
  end

  it "should allow accessing the reconcile page" do
    get '/reconcile'
    expect(last_response).to be_ok
  end

end
