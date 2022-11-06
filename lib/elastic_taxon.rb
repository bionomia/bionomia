# encoding: utf-8
require_relative "elastic_indexer"

module Bionomia
  class ElasticTaxon < ElasticIndexer

    def initialize(opts = {})
      super
      @settings = { index: Settings.elastic.taxon_index }.merge(opts)
    end

    def create_index
      config = {
        settings: {
          analysis: {
            filter: {
              autocomplete: {
                type: "edge_ngram",
                side: "front",
                min_gram: 1,
                max_gram: 50
              },
            },
            analyzer: {
              taxon_analyzer: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding", :autocomplete]
              }
            }
          }
        },
        mappings: {
          properties: {
            id: { type: 'integer', index: false },
            name: {
              type: 'text',
              search_analyzer: :standard,
              analyzer: :taxon_analyzer,
              norms: false
            }
          }
        }
      }
      client.indices.create index: @settings[:index], body: config
    end

    def import
      Taxon.find_in_batches do |batch|
        bulk(batch)
      end
    end

    def document(t)
      {
        id: t.id,
        name: t.family
      }
    end

  end
end
