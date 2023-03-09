describe "Identifier library" do

  it "extracts an IPNI id an IPNI URL with value 13860-1" do
    url = "https://www.ipni.org/ipni/idAuthorSearch.do?id=13860-1"
    id = "13860-1"
    expect(url.ipni_from_url).to eq id
  end

  it "extracts an ORCID id from an ORCID URL with value 0000-0002-7101-9767" do
    url = "https://orcid.org/0000-0002-7101-9767"
    id = "0000-0002-7101-9767"
    expect(url.orcid_from_url).to eq id
  end

  it "extracts an VIAF id from an VIAF URL with value 120062731/" do
    url = "https://viaf.org/viaf/120062731/"
    id = "120062731"
    expect(url.viaf_from_url).to eq id
  end

  it "extracts an VIAF id from an VIAF URL with value 120062739" do
    url = "https://viaf.org/viaf/120062739"
    id = "120062739"
    expect(url.viaf_from_url).to eq id
  end

  it "extracts a wiki Q number from a wikidata URL with value Q3518898" do
    url = "http://www.wikidata.org/entity/Q3518898"
    id = "Q3518898"
    expect(url.wiki_from_url).to eq id
  end

  it "extracts a BHL creator ID from a BHL URL with value 1368" do
    url = "http://www.biodiversitylibrary.org/creator/1368"
    id = "1368"
    expect(url.bhl_from_url).to eq id
  end

  it "extracts an ISNI from an ISNI URL with value 0000 0001 2146 438X" do
    url = "http://www.isni.org/0000+0001+2146+438X"
    id = "0000 0001 2146 438X"
    expect(url.isni_from_url).to eq id
  end

  it "extracts a ZooBank Author ID with value B3C52D0E-E3FF-454B-B342-9235AB7E1545" do
    url = "http://zoobank.org/Authors/B3C52D0E-E3FF-454B-B342-9235AB7E1545"
    id = "B3C52D0E-E3FF-454B-B342-9235AB7E1545"
    expect(url.zoobank_from_url).to eq id
  end

  it "extracty a Library of Congress Authority ID with value n91033477" do
    url = "http://id.loc.gov/authorities/names/n91033477"
    id = "n91033477"
    expect(url.library_congress_from_url).to eq id
  end

  it "determines that https://orcid.org/0000-0002-4519-8167 is a valid ORCID" do
    url = "https://orcid.org/0000-0002-4519-8167"
    expect(url.orcid_from_url.is_orcid?).to be true
  end

  it "determines that https://orcid.org/0000-0002-4519-8165 is an invalid ORCID" do
    url = "https://orcid.org/0000-0002-4519-8165"
    expect(url.orcid_from_url.is_orcid?).to be false
  end

  it "determines that https://orcid.org/0000-0002-6662-847X is a valid ORCID" do
    url = "https://orcid.org/0000-0002-6662-847X"
    expect(url.orcid_from_url.is_orcid?).to be true
  end

  it "determines that https://orcid.org/0000-0002-6662-846X is an invalid ORCID" do
    url = "https://orcid.org/0000-0002-6662-846X"
    expect(url.orcid_from_url.is_orcid?).to be false
  end

  it "determines that https://orcid.org/0009-0006-7586-1763 is a valid ORCID" do
    url = "https://orcid.org/0009-0006-7586-1763"
    expect(url.orcid_from_url.is_orcid?).to be true
  end

  it "determines that A_0aadf4h_O is a valid Youtube ID" do
    id = "A_0aadf4h_O"
    expect(id.is_youtube_id?).to be true
  end

  it "determines that A_0aadf4h_OA is an invalid Youtube ID" do
    id = "A_0aadf4h_OA"
    expect(id.is_youtube_id?).to be false
  end

end
