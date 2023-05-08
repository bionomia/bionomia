# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module QueryHelper

        def build_name_query(search, obj = {})
          qry = {
              query: {
                bool: {
                  must: [
                    {
                      multi_match: {
                        query:      search,
                        type:       :cross_fields,
                        analyzer:   :fullname_index,
                        fields:     [
                          "family^3",
                          "given",
                          "fullname^5",
                          "label",
                          "other_names",
                          "*.edge"
                        ],
                      }
                    }
                  ],
                  should: [
                    rank_feature: {
                      field: "rank"
                    }
                  ],
                  filter: []
                }
              },
              sort: [
                "_score",
                { family: { order: :asc } },
                { given: { order: :asc } }
              ]
            }
          if obj.has_key? :is_public
            qry[:query][:bool][:filter] << { term: { is_public: obj[:is_public] } }
          end
          if obj.has_key? :has_occurrences
            qry[:query][:bool][:filter] << { term: { has_occurrences: obj[:has_occurrences] } }
          end
          qry
        end

        def build_organization_query(search)
          {
            query: {
              multi_match: {
                query: search,
                type: :best_fields,
                fields: ["institution_codes^5", "name^3", "address"]
              }
            }
          }
        end

        def build_taxon_query(search)
          {
            query: {
              match: {
                name: search
              }
            }
          }
        end

        def build_dataset_query(search)
          {
            query: {
              function_score: {
                query: {
                  multi_match: {
                    query: search,
                    type: :best_fields,
                    fields: ["top_collection_codes^5", "top_institution_codes^3", "title^3", "description"]
                  }
                },
                functions: [
                  {
                    filter: { match: { kind: "OCCURRENCE" } },
                    weight: 5
                  },
                  {
                    filter: { match: { kind: "CHECKLIST" } },
                    weight: 1
                  }
                ]
              }
            }
          }
        end

        def build_article_query(search)
          {
            query: {
              multi_match: {
                query: search,
                type: :best_fields,
                fields: ["citation^3", "abstract"]
              }
            },
            highlight: {
              fields: {
                citation: { number_of_fragments: 0, no_match_size: 5_000, pre_tags: ["<mark>"], post_tags: ["</mark>"] },
                abstract: { pre_tags: ["<mark>"], post_tags: ["</mark>"] }
              }
            }
          }
        end

        def build_user_country_query(countryCode, action = nil, family = nil, profile_type = "id")
          if !action.nil?
            qry = {
              sort: [
                { "family.keyword": "asc" }
              ],
              query: {
                bool: {
                  must: [
                    { exists: { field: profile_type } },
                    { nested: {
                        path: action,
                        query: {
                          bool: {
                            must: [
                              { term: { "#{action}.country": { value: countryCode } } }
                            ]
                          }
                        }
                      }
                    }
                  ]
                }
              }
            }
            if family
              qry[:query][:bool][:must][1][:nested][:query][:bool][:must] << { term: { "#{action}.family": { value: family } } }
            end
          else
            qry = {
              sort: [
                { "family.keyword": "asc" }
              ],
              query: {
                bool: {
                  must: [
                    { exists: { field: profile_type } },
                    {
                      bool: {
                        should: [
                          {
                            nested: {
                              path: "recorded",
                              query: {
                                bool: {
                                  must: [
                                    { term: { "recorded.country": { value: countryCode } } }
                                  ]
                                }
                              }
                            }
                          },
                          {
                            nested: {
                              path: "identified",
                              query: {
                                bool: {
                                  must: [
                                    { term: { "identified.country": { value: countryCode } } }
                                  ]
                                }
                              }
                            }
                          }
                        ]
                      }
                    }
                  ]
                }
              }
            }
            if family
              qry[:query][:bool][:must][1][:bool][:should][0][:nested][:query][:bool][:must] << { term: { "recorded.family": { value: family } } }
              qry[:query][:bool][:must][1][:bool][:should][1][:nested][:query][:bool][:must] << { term: { "identified.family": { value: family } } }
            end
          end
          qry
        end

        def build_user_taxon_query(family, type = nil)
          if !type.nil?
            qry = {
              sort: [
                { "family.keyword": "asc" }
              ],
              query: {
                nested: {
                  path: type,
                  query: {
                    bool: {
                      must: [
                        { term: { "#{type}.family": { value: family } } }
                      ]
                    }
                  }
                }
              }
            }
          else
            qry = {
              sort: [
                { "family.keyword": "asc" }
              ],
              query: {
                bool: {
                  should: [
                    {
                      nested: {
                        path: "recorded",
                        query: {
                          bool: {
                            must: [
                              { term: { "recorded.family": { value: family } } }
                            ]
                          }
                        }
                      }
                    },
                    {
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
                  ]
                }
              }
            }
          end
          qry
        end

      end
    end
  end
end
