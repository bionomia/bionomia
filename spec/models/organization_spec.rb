describe "Organization model" do

  it "is valid without any data" do
    o = Organization.new
    o.skip_callbacks
    expect(o).to be_valid
  end

end
