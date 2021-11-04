# encoding: utf-8
require_relative "elastic_indexer"

module Bionomia
  class ElasticUser < ElasticIndexer

    def initialize(opts = {})
      super
      @settings = { index: Settings.elastic.user_index }.merge(opts)
      client.transport.reload_connections!
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
            orcid: { type: 'keyword', index: false },
            wikidata: { type: 'keyword', index: false },
            thumbnail: { type: 'keyword', index: false },
            description: { type: 'text', index: false },
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
              analyzer: :name_part_index,
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
      User.where.not(family: [nil, ""])
          .where.not(id: User::BOT_IDS)
          .find_in_batches do |batch|
        bulk(batch)
      end
    end

    def thumbnail(u)
      img = Settings.base_url + "/images/photo24X24.png"
      cloud_img = "https://abekpgaoen.cloudimg.io/crop/24x24/n/"
      if u.image_url
        if u.wikidata
          img =  cloud_img + u.image_url
        else
          img = cloud_img + Settings.base_url + "/images/users/" + u.image_url
        end
      end
      img
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
                       .map{|o| { id: o.id, orcid: o.orcid, wikidata: o.wikidata, fullname: o.fullname } }
      recorded_countries = u.recorded_families_countries
      rank = recorded_countries.map{|a| a[:family]}.uniq.compact.count
      {
        id: u.id,
        orcid: u.orcid,
        wikidata: u.wikidata,
        family: u.family,
        given: u.given,
        fullname: u.fullname,
        fullname_reverse: u.fullname_reverse,
        other_names: other_names,
        date_born: u.date_born,
        date_born_precision: u.date_born_precision,
        date_died: u.date_died,
        date_died_precision: u.date_died_precision,
        thumbnail: thumbnail(u),
        description: description,
        identified: u.identified_families_countries,
        recorded: recorded_countries,
        co_collectors: co_collectors,
        rank: ((rank.nil? || rank == 0) ? nil : rank)
      }
    end

  end
end
