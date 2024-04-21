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
          index: {
            number_of_replicas: 0,
            auto_expand_replicas: false
          },
          analysis: {
            filter: {
              autocomplete: {
                type: "edge_ngram",
                side: "front",
                min_gram: 4,
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
              analyzer: :organization_index,
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
      Parallel.each((Organization.minimum(:id)..Organization.maximum(:id)).each_slice(2_400), progress: "Rebuilding organization index", in_threads: 6) do |ids|
        bulk(Organization.where(id: ids))
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
