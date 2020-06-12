describe "Organization model" do

  it "is valid without any data" do
    o = Organization.new
    expect(o).to be_valid
  end

end