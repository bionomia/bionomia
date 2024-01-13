# encoding: utf-8

module Bionomia
   class ZenodoDataset < Zenodo

      def initialize(**args)
         super(**args)
      end
   
      def package_metadata
         {
            upload_type: "dataset",
            title: "Linked collectors and determiners for: #{@resource.title}.",
            creators:  [ { name: "Bionomia" } ],
            description: "Natural history specimen data linked to collectors and determiners held within, \"#{@resource.title}\". Claims or attributions were made on Bionomia by volunteer Scribes, <a href=\"http://bionomia.net/dataset/#{@resource.uuid}\">https://bionomia.net/dataset/#{@resource.uuid}</a> using specimen data from the dataset aggregated by the Global Biodiversity Information Facility, <a href=\"https://gbif.org/dataset/#{@resource.uuid}\">https://gbif.org/dataset/#{@resource.uuid}</a>. Formatted as a Frictionless Data package.",
            access_right: "open",
            license: "cc-zero",
            keywords: ["specimen", "natural history", "taxonomy"],
            communities: [{ identifier: 'bionomia' }],
            related_identifiers: [{ identifier: "#{@resource.doi}", relation: 'isDerivedFrom' }]
         }
      end

      def token_hash
         @token_hash ||= { access_token: @settings.zenodo.access_token }
      end

  end
end