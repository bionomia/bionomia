# encoding: utf-8
require_relative "elastic_indexer"

module Bionomia
  class ElasticAgent < ElasticIndexer

    def initialize(opts = {})
      super
      @settings = { index: Settings.elastic.agent_index }.merge(opts)
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
            tokenizer: {
              simple_split: {
                type: "simple_pattern_split",
                pattern: "\\.|\\,| "
              }
            },
            analyzer: {
              name_part_index: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase", "asciifolding", "german_normalization"]
              },
              name_part_search: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase", "asciifolding", "german_normalization", :autocomplete]
              },
              fullname_index: {
                type: "custom",
                tokenizer: :simple_split,
                filter: ["lowercase", "asciifolding", "german_normalization"]
              },
              fullname_search: {
                type: "custom",
                tokenizer: :simple_split,
                filter: ["lowercase", "asciifolding", "german_normalization", :autocomplete]
              }
            }
          }
        },
        mappings: {
          properties: {
            id: { type: 'integer', index: false },
            family: {
              type: 'text',
              fielddata: true,
              analyzer: :name_part_index,
              norms: false,
              fields: {
                edge: {
                  type: 'text',
                  search_analyzer: :name_part_search,
                  analyzer: :name_part_search,
                  norms: false,
                }
              }
            },
            given: {
              type: 'text',
              fielddata: true,
              analyzer: :name_part_index,
              norms: false,
              fields: {
                edge: {
                  type: 'text',
                  search_analyzer: :name_part_search,
                  analyzer: :name_part_search,
                  norms: false,
                }
              }
            },
            fullname: {
              type: 'text',
              analyzer: :fullname_index,
              search_analyzer: :fullname_search,
              norms: false
            },
            fullname_reverse: {
              type: 'text',
              norms: false
            },
            rank: {
              type: 'rank_feature'
            }
          }
        }
      }
      client.indices.create index: @settings[:index], body: config
    end

    def import
      Parallel.each(Agent.find_in_batches(batch_size: 5_000), progress: "Rebuilding agent index", in_threads: 4) do |batch|
        bulk(batch)
      end
    end

    def document(a)
      {
        id: a.id,
        family: a.family,
        given: a.given,
        fullname: a.fullname,
        fullname_reverse: a.fullname_reverse,
        rank: nil
      }
    end

  end
end
