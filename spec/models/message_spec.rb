describe "Message model" do

  it "is not valid without a user_id" do
    message = Message.new(user_id: nil, recipient_id: 1)
    expect(message).to_not be_valid
  end

  it "is not valid without a recipient_id" do
    message = Message.new(user_id: 1, recipient_id: nil)
    expect(message).to_not be_valid
  end

  it "is valid with a user_id and a recipient_id" do
    message = Message.new(user_id: 1, recipient_id: 2)
    expect(message).to be_valid
  end

end
