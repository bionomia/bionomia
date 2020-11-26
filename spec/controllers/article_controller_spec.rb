describe "Bionomia Article Controller" do

  it "should allow accessing the articles page" do
    get '/articles'
    expect(last_response).to be_ok
  end

end
