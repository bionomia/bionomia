describe "DestroyedUser model" do

  it "is not valid without an identifier" do
    destroyed_user = DestroyedUser.new(identifier: nil, redirect_to: "Q12345")
    expect(destroyed_user).to_not be_valid
  end

  it "is valid without a redirect" do
    destroyed_user = DestroyedUser.new(identifier: "Q12345", redirect_to: nil)
    expect(destroyed_user).to be_valid
  end

  it "is valid with an identifier and a redirect" do
    destroyed_user = DestroyedUser.new(identifier: "Q12345", redirect_to: "Q12346")
    expect(destroyed_user).to be_valid
  end

end