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
              organization_search: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding", :autocomplete]
              },
              organization_index: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding"]
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
            id: { type: 'integer', index: false },
            name: {
              type: 'text',
              search_analyzer: :organization_search,
              analyzer: :organization_index,
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
            isni: { type: 'keyword', index: false },
            ringgold: { type: 'keyword', index: false },
            grid: { type: 'keyword', index: false },
            ror: { type: 'keyword', index: false },
            wikidata: { type: 'keyword', index: false },
            preferred: { type: 'keyword', index: false }
          }
        }
      }
      client.indices.create index: @settings[:index], body: config
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
        ror: o.ror,
        ringgold: o.ringgold,
        wikidata: o.wikidata,
        preferred: o.identifier
      }
    end

  end
end
