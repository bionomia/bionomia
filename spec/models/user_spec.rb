describe "User model" do

  it "is valid with any data" do
    u = User.new
    expect(u).to be_valid
  end

end