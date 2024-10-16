# encoding: utf-8

module Bionomia
  class ZenodoUser < Zenodo

    def initialize(**args)
        super(**args)
    end

    def creator
      if @resource.orcid
        { name: @resource.viewname, orcid: @resource.orcid }
      else
        { name: @resource.viewname }
      end
    end
   
    def package_metadata
      hash = {
        upload_type: "dataset",
        title: "Natural history specimens collected and/or identified and deposited.",
        creators:  [ creator ],
        description: "Natural history specimen data collected and/or identified by #{@resource.viewname}, <a href=\"#{@resource.uri}\">#{@resource.uri}</a>. Claims or attributions were made on Bionomia, <a href=\"http://bionomia.net\">https://bionomia.net</a> using specimen data from the Global Biodiversity Information Facility, <a href=\"https://gbif.org\">https://gbif.org</a>.",
        access_right: "open",
        license: "cc-zero",
        keywords: ["specimen", "natural history", "taxonomy"],
        communities: [{ identifier: 'bionomia' }]
      }
      if @resource.wikidata
        hash.merge!({ notes: @resource.uri })
      end
      hash
    end

    def token_hash
      @token_hash ||= ( @resource.orcid ? @resource.zenodo_access_token : { access_token: @settings.zenodo.access_token } )
    end

  end
end