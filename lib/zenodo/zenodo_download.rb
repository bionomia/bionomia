# encoding: utf-8

module Bionomia
  class ZenodoDownload < Zenodo

    def initialize(**args)
      super(**args)
    end
  
    def package_metadata
      {
        upload_type: "dataset",
        title: "Public profiles and attributions made on Bionomia.",
        creators:  [ { name: "Bionomia" } ],
        description: "Public profiles and claims or attributions of natural history specimens made for collectors and determiners on Bionomia, <a href=\"http://bionomia.net\">https://bionomia.net</a> using data from the Global Biodiversity Information Facility, <a href=\"https://gbif.org\">https://gbif.org</a>.",
        access_right: "open",
        license: "cc-zero",
        keywords: ["specimen", "natural history", "taxonomy"],
        communities: [{ identifier: 'bionomia' }]
      }
    end

    def token_hash
      @token_hash ||= { access_token: @settings.zenodo.access_token }
    end

  end
end