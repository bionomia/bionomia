# encoding: utf-8
require_relative "elastic_indexer"

module Bionomia
  class ElasticUser < ElasticIndexer

    def initialize(opts = {})
      @img = Class.new
      @img.extend Sinatra::Bionomia::Helper::ImageHelper
      super
      @settings = { index: Settings.elastic.user_index }.merge(opts)
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
              synonym: {
                type: "synonym",
                synonyms_path: "synonyms.txt"
              }
            },
            normalizer: {
              taxa: {
                type: "custom",
                filter: ["lowercase"]
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
              given_name_index: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase", "asciifolding", "german_normalization", :synonym]
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
            orcid: { type: 'keyword' },
            wikidata: { type: 'keyword' },
            thumbnail: { type: 'keyword', index: false },
            image: { type: 'keyword', index: false },
            description: { type: 'text', index: false },
            is_public: { type: 'boolean' },
            has_occurrences: { type: 'boolean' },
            family: {
              type: 'text',
              fielddata: true,
              analyzer: :name_part_index,
              norms: false,
              fields: {
                keyword: {
                  type: 'keyword',
                  norms: false
                },
                edge: {
                  type: 'text',
                  analyzer: :name_part_search,
                  search_analyzer: :name_part_search,
                  norms: false,
                }
              }
            },
            given: {
              type: 'text',
              fielddata: true,
              analyzer: :given_name_index,
              norms: false,
              fields: {
                edge: {
                  type: 'text',
                  analyzer: :name_part_search,
                  search_analyzer: :name_part_search,
                  norms: false,
                }
              }
            },           
            label: {
              type: 'text',
              analyzer: :fullname_index,
              search_analyzer: :fullname_search,
              norms: false
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
            other_names: {
              type: 'text',
              analyzer: :fullname_index,
              search_analyzer: :fullname_search,
              norms: false
            },
            date_born: {
              type: 'date',
              format: 'yyyy-MM-dd'
            },
            date_born_precision: {
              type: 'keyword',
              norms: false
            },
            date_died: {
              type: 'date',
              format: 'yyyy-MM-dd'
            },
            date_died_precision: {
              type: 'keyword',
              norms: false
            },
            recorded: {
              type: 'nested',
              properties: {
                family: {
                  type: 'keyword',
                  normalizer: :taxa,
                  norms: false
                },
                country: {
                  type: 'keyword',
                  norms: false
                }
              }
            },
            identified: {
              type: 'nested',
              properties: {
                family: {
                  type: 'keyword',
                  normalizer: :taxa,
                  norms: false
                },
                country: {
                  type: 'keyword',
                  norms: false
                }
              }
            },
            co_collectors: {
              type: 'nested',
              properties: {
                id: { type: 'integer', index: false },
                orcid: { type: 'keyword', index: false },
                wikidata: { type: 'keyword', index: false },
                fullname: {
                  type: 'text',
                  analyzer: :fullname_index,
                  search_analyzer: :fullname_search,
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
      batches = User.where.not(family: [nil, ""])
                    .where.not(id: User::BOT_IDS)
                    .find_in_batches
      Parallel.each(batches, progress: "Rebuilding user index", in_threads: 3) do |batch|
        bulk(batch)
      end
    end

    def document(u)
      description = nil
      if u.description
        description = u.description.truncate(80)
      elsif u.keywords
        description = u.keywords.split("|").map(&:strip).join(", ").truncate(80)
      end
      other_names = u.other_names.split("|").map(&:strip) rescue []
      co_collectors = u.recorded_with
                       .map{|o| { id: o.id, orcid: o.orcid, wikidata: o.wikidata, fullname: o.viewname } }
      family_countries = u.families_countries
      rank = family_countries[:recorded].map{|a| a[:family]}.uniq.compact.count
      {
        id: u.id,
        orcid: u.orcid,
        wikidata: u.wikidata,
        family: u.family,
        given: u.given,
        label: u.label,
        fullname: u.fullname,
        fullname_reverse: u.fullname_reverse,
        other_names: other_names,
        date_born: u.date_born,
        date_born_precision: u.date_born_precision,
        date_died: u.date_died,
        date_died_precision: u.date_died_precision,
        thumbnail: @img.profile_image(u, "thumbnail"),
        image: @img.profile_image(u),
        description: description,
        is_public: u.is_public,
        has_occurrences: (u.has_recordings? || u.has_identifications?),
        identified: family_countries[:identified].to_a,
        recorded: family_countries[:recorded].to_a,
        co_collectors: co_collectors,
        rank: ((rank.nil? || rank == 0) ? nil : rank)
      }
    end

    def by_identified(family:, size: 10)
      body = {
        query: {
          function_score: {
            random_score: {
              seed: Time.now.to_i
            },
            query: {
              nested: {
                path: "identified",
                query: {
                  bool: {
                    must: [
                      { term: { "identified.family": { value: family } } }
                    ]
                  }
                }
              }
            }
          }
        }
      }
      client.search index: @settings[:index], body: body, size: size, scroll: "1m"
    end

  end
end
