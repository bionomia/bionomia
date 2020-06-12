describe "UserOrganization model" do

  it "is not valid without a user_id" do
    uo = UserOrganization.new(user_id: nil, organization_id: 1)
    expect(uo).to_not be_valid
  end

  it "is not valid without an organization_id" do
    uo = UserOrganization.new(user_id: 1, organization_id: nil)
    expect(uo).to_not be_valid
  end

  it "is valid with a user_id and an organization_id" do
    uo = UserOrganization.new(user_id: 1, organization_id: 1)
    expect(uo).to be_valid
  end

end