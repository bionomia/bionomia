describe "UserOccurrence model" do

  it "is not valid without a user_id" do
    uo = UserOccurrence.new(user_id: nil, occurrence_id: 1, created_by: 1)
    expect(uo).to_not be_valid
  end

  it "is valid without an occurrence_id" do
    uo = UserOccurrence.new(user_id: 1, occurrence_id: nil, created_by: 1)
    expect(uo).to_not be_valid
  end

  it "is not valid without a created_by" do
    uo = UserOccurrence.new(user_id: 1, occurrence_id: 1, created_by: nil)
    expect(uo).to_not be_valid
  end

  it "is valid with a user_id, an occurrence_id, and a created_by" do
    uo = UserOccurrence.new(user_id: 1, occurrence_id: 1, created_by: 1)
    expect(uo).to be_valid
  end

end