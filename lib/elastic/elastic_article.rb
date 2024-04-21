# encoding: utf-8
require_relative "elastic_indexer"

module Bionomia
  class ElasticArticle < ElasticIndexer

    def initialize(opts = {})
      super
      @settings = { index: Settings.elastic.article_index }.merge(opts)
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
                min_gram: 1,
                max_gram: 50
              },
            },
            analyzer: {
              paper_analyzer: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding", :autocomplete]
              }
            }
          }
        },
        mappings: {
          properties: {
            id: { type: 'text', index: false },
            doi: { type: 'keyword', index: false },
            citation: {
              type: 'text',
              search_analyzer: :standard,
              analyzer: :paper_analyzer,
              norms: false
            },
            abstract: {
              type: 'text',
              analyzer: :standard,
              norms: false
            }
          }
        }
      }
      client.indices.create index: @settings[:index], body: config
    end

    def import
      Parallel.each((Article.minimum(:id)..Article.maximum(:id)).each_slice(1_000), progress: "Rebuilding article index", in_threads: 4) do |ids|
        bulk(Article.where(id: ids))
      end
    end

    def document(d)
      {
        id: d.id,
        doi: d.doi,
        citation: d.citation,
        abstract: d.abstract
      }
    end

  end
end
