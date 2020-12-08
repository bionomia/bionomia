describe "Bionomia Occurrence Controller" do
  before(:each) do
    @id = 1
    @occurrence = Occurrence.create!({ gbifID: @id })
  end

  after(:each) do
    @occurrence.destroy
  end

  it "should allow accessing an occurrence page" do
    get '/occurrence/' + @id.to_s
    expect(last_response).to be_ok
  end

  it "should allow accessing an occurrence json-ld page" do
    get '/occurrence/' + @id.to_s + '.json'
    expect(last_response).to be_ok
  end

end
