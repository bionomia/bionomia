# encoding: utf-8
require_relative "elastic_indexer"

module Bionomia
  class ElasticDataset < ElasticIndexer

    def index
      Settings.elastic.dataset_index
    end

    def config
      {
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
            datasetkey: { type: 'keyword' },
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
            },
            top_collection_codes: {
              type: 'text',
              analyzer: :institution_codes,
              norms: false
            },
            kind: {
              type: 'text',
              analyzer: :institution_codes,
              norms: false
            },
            users_count: { type: 'integer', index: false }
          }
        }
      }
    end

    def import
      Parallel.each((Dataset.minimum(:id)..Dataset.maximum(:id)).each_slice(12), progress: "Rebuilding dataset index", in_threads: 4) do |ids|
        bulk(Dataset.where(id: ids))
      end
    end

    def document(d)
      {
        id: d.id,
        datasetkey: d.uuid,
        title: d.title,
        description: (d.description.gsub(/<\/?[^>]*>/, "") rescue nil),
        top_collection_codes: d.top_collection_codes,
        top_institution_codes: d.top_institution_codes,
        kind: d.dataset_type,
        users_count: d.users_count
      }
    end

  end
end
