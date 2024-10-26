# encoding: utf-8
require_relative "elastic_indexer"

module Bionomia
  class ElasticTaxon < ElasticIndexer

    def index
      Settings.elastic.taxon_index
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
    end

    def import
      Parallel.each((Taxon.minimum(:id)..Taxon.maximum(:id)).each_slice(2_400), progress: "Rebuilding taxon index", in_threads: 6) do |ids|
        bulk(Taxon.where(id: ids))
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
