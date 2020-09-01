# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module QueryHelper

        def build_name_query(search)
          {
            query: {
              multi_match: {
                query:      search,
                type:       :cross_fields,
                analyzer:   :fullname_index,
                fields:     ["family^5", "given^3", "fullname", "other_names", "*.edge"],
              }
            }
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

        def build_dataset_query(search)
          {
            query: {
              multi_match: {
                query: search,
                type: :best_fields,
                fields: ["top_institution_codes^5", "title^3", "description"]
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

      end
    end
  end
end
