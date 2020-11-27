# encoding: utf-8
require_relative "elastic_indexer"

module Bionomia
  class ElasticDataset < ElasticIndexer

    def initialize(opts = {})
      super
      @settings = { index: Settings.elastic.dataset_index }.merge(opts)
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
              dataset_analyzer: {
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
            id: { type: 'integer', index: false },
            datasetkey: { type: 'text', index: false },
            title: {
              type: 'text',
              search_analyzer: :standard,
              analyzer: :dataset_analyzer,
              norms: false
            },
            description: {
              type: 'text',
              analyzer: :standard,
              norms: false
            },
            top_institution_codes: {
              type: 'text',
              analyzer: :institution_codes,
              norms: false
            }
          }
        }
      }
      @client.indices.create index: @settings[:index], body: config
    end

    def import
      Dataset.find_in_batches do |batch|
        bulk(batch)
      end
    end

    def document(d)
      {
        id: d.id,
        datasetkey: d.datasetKey,
        title: d.title,
        description: d.description,
        top_institution_codes: d.top_institution_codes
      }
    end

  end
end
