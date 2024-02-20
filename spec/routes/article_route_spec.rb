describe "Bionomia Article Route" do
  before(:each) do
    @doi = "10.0000/12345"
    gbif_dois = ["10.0001/1", "10.0001/2"]
    gbif_downloadkeys = ["123x", "123y"]
    @article = Article.new({ doi: @doi, gbif_dois: gbif_dois, gbif_downloadkeys: gbif_downloadkeys })
    @article.skip_callbacks = true
    @article.save
  end

  after(:each) do
    @article.destroy
  end

  it "should allow accessing the articles page" do
    get '/articles'
    expect(last_response).to be_ok
  end

  it "should allow accessing an article page" do
    get '/article/' + @doi
    expect(last_response).to be_ok
  end

  it "should allow accessing an article agents page" do
    get '/article/' + @doi + '/agents'
    expect(last_response.status).to eq(403)
  end

  it "should allow accessing an article agent counts page" do
    get '/article/' + @doi + '/agents/counts'
    expect(last_response.status).to eq(403)
  end

  it "should allow accessing an article agent unclaimed page" do
    get '/article/' + @doi + '/agents/unclaimed'
    expect(last_response.status).to eq(403)
  end

end
