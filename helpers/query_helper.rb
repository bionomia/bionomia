# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module QueryHelper

        def build_name_query(search)
          {
            query: {
              bool: {
                must: [
                  multi_match: {
                    query:      search,
                    type:       :cross_fields,
                    analyzer:   :fullname_index,
                    fields:     [
                      "family^3",
                      "given",
                      "fullname^5",
                      "other_names",
                      "*.edge"
                    ],
                  }
                ],
                should: [
                  rank_feature: {
                    field: "rank"
                  }
                ]
              }
            },
            sort: [
              "_score",
              { family: { order: :asc } },
              { given: { order: :asc } }
            ]
          }
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
                    fields: ["top_institution_codes^5", "title^3", "description"]
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
            }
          }
        end

        def build_user_country_query(countryCode, type = nil, family = nil)
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
                        { term: { "#{type}.country": { value: countryCode } } }
                      ]
                    }
                  }
                }
              }
            }
            if family
              qry[:query][:nested][:query][:bool][:must] << { term: { "#{type}.family": { value: family } } }
            end
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
            }
            if family
              qry[:query][:bool][:should][0][:nested][:query][:bool][:must] << { term: { "recorded.family": { value: family } } }
              qry[:query][:bool][:should][1][:nested][:query][:bool][:must] << { term: { "identified.family": { value: family } } }
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
