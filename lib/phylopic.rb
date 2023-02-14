# encoding: utf-8

module Bionomia
  class Phylopic

    def initialize
      response = RestClient::Request.execute(
          method: :get,
          headers: { accept: 'application/vnd.phylopic.v2+json' },
          url: "https://api.phylopic.org/"
        )
      build = JSON.parse(response, symbolize_names: true)[:build]
      @url = "https://api.phylopic.org/nodes?build=#{build}&embed_items=true&embed_primaryImage=true&page=0&filter_name="
    end
        
    def search(family:)
      begin
        response = RestClient::Request.execute(
          method: :get,
          headers: { accept: 'application/vnd.phylopic.v2+json' },
          url: "#{@url}#{family.downcase}"
        )
        hash = JSON.parse(response, symbolize_names: true)
        image_metadata = hash[:_embedded][:items][0][:_embedded][:primaryImage]
        url = nil
        image_metadata[:_links][:thumbnailFiles].each do |thumbnail|
          if thumbnail[:sizes] == "64x64"
            url = thumbnail[:href]
            break
          end
        end
        {
          family: family,
          url: url,
          credit: image_metadata[:attribution],
          licenseURL: image_metadata[:_links][:license][:href]
        }
      rescue
        {}
      end
    end

    def upsert(family:)
      content = search(family: family)
      if !content.blank?
        file_name = "#{content[:url].split("/")[4]}.64.png"
        read_image = URI.open(content[:url]).read
        File.open(File.join(BIONOMIA.root, BIONOMIA.public_folder, 'images', 'taxa', file_name), 'wb') do |file|
          file.write read_image
        end
        TaxonImage.upsert({
          family: family,
          file_name: file_name,
          credit: content[:credit],
          licenseURL: content[:licenseURL]
        })
      end
    end

  end
end