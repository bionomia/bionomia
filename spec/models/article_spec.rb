describe "Article model" do

  it "is not valid without a DOI" do
    article = Article.new(doi: nil, citation: nil, gbif_dois: ["10.9999"], gbif_downloadkeys: ["0000-0000"])
    article.skip_callbacks
    expect(article).to_not be_valid
  end

  it "is not valid without gbif_dois" do
    article = Article.new(doi: "10.9999", citation: nil, gbif_dois: [], gbif_downloadkeys: ["0000-0000"])
    article.skip_callbacks
    expect(article).to_not be_valid
  end

  it "is not valid without gbif_downloadkeys" do
    article = Article.new(doi: "10.9999", citation: nil, gbif_dois: ["10.9999"], gbif_downloadkeys: [])
    article.skip_callbacks
    expect(article).to_not be_valid
  end

  it "is valid when we've got everything we need" do
    article = Article.new(doi: "10.9999", citation: nil, gbif_dois: ["10.9999"], gbif_downloadkeys: ["0000-0000"])
    article.skip_callbacks
    expect(article).to be_valid
  end

end
