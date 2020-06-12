describe "ArticleOccurrence model" do

  it "is not valid without an occurrence_id" do
    ao = ArticleOccurrence.new(occurrence_id: nil, article_id: 1)
    expect(ao).to_not be_valid
  end

  it "is not valid without an article_id" do
    ao = ArticleOccurrence.new(occurrence_id: 1, article_id: nil)
    expect(ao).to_not be_valid
  end

  it "is valid with an article_id and an occurrence_id" do
    ao = ArticleOccurrence.new(occurrence_id: 1, article_id: 1)
    expect(ao).to be_valid
  end

end