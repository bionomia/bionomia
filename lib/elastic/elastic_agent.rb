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
              initials: {
                type: "pattern_replace",
                pattern: "[a-z\\.\\s]",
                replacement: ""
              }
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
              },
              unparsed_index: {
                type: "custom",
                tokenizer: "keyword",
                filter: [:initials, "lowercase", "asciifolding"]
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
            unparsed: {
              type: 'text',
              fielddata: true,
              analyzer: :standard,
              norms: false,
              fields: {
                keyword: {
                  type: 'text',
                  analyzer: :unparsed_index,
                  search_analyzer: :unparsed_index,
                  norms: false
                }
              }
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
      Parallel.each((Agent.minimum(:id)..Agent.maximum(:id)).each_slice(2_400), progress: "Rebuilding agent index", in_threads: 6) do |ids|
        bulk(Agent.where(id: ids))
      end
    end

    def document(a)
      {
        id: a.id,
        family: a.family,
        given: a.given,
        fullname: a.fullname,
        fullname_reverse: a.fullname_reverse,
        unparsed: a.unparsed,
        rank: ((a.given.blank? && a.family.blank?) ? nil : 1)
      }
    end

  end
end
