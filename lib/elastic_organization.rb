# encoding: utf-8
require_relative "elastic_indexer"

module Bionomia
  class ElasticOrganization < ElasticIndexer

    def initialize(opts = {})
      super
      @settings = { index: Settings.elastic.organization_index }.merge(opts)
    end

    def create_index
      config = {
        settings: {
          analysis: {
            filter: {
              autocomplete: {
                type: "edgeNGram",
                side: "front",
                min_gram: 1,
                max_gram: 50
              },
            },
            analyzer: {
              organization_analyzer: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding", :autocomplete]
              },
              institution_codes: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase"]
              }
            }
          }
        },
        mappings: {
          properties: {
            id: { type: 'text', index: false },
            name: {
              type: 'text',
              search_analyzer: :standard,
              analyzer: :organization_analyzer,
              norms: false
            },
            address: {
              type: 'text',
              search_analyzer: :standard,
              analyzer: :organization_analyzer,
              norms: false
            },
            institution_codes: {
              type: 'text',
              analyzer: :institution_codes,
              norms: false
            },
            isni: { type: 'text', index: false },
            ringgold: { type: 'text', index: false },
            grid: { type: 'text', index: false },
            wikidata: { type: 'text', index: false },
            preferred: { type: 'text', index: false }
          }
        }
      }
      @client.indices.create index: @settings[:index], body: config
    end

    def import
      Organization.find_in_batches do |batch|
        bulk(batch)
      end
    end

    def document(o)
      {
        id: o.id,
        name: o.name,
        address: o.address,
        institution_codes: o.institution_codes,
        isni: o.isni,
        grid: o.grid,
        ringgold: o.ringgold,
        wikidata: o.wikidata,
        preferred: o.identifier
      }
    end

  end
end
