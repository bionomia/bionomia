# encoding: utf-8
require_relative "frictionless_table"

module Bionomia
  class FrictionlessTableCitation < FrictionlessTable

    def resource
      {
        name: "article-occurrences",
        description: "Citations of articles",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "article_id", type: "integer" },
            { name: "occurrence_id", type: "integer" }
          ]
        },
        foreignKeys: [
          {
            fields: "article_id",
            reference: {
              resource: "articles",
              fields: "id"
            }
          },
          {
            fields: "occurrence_id",
            reference: {
              resource: "occurrences",
              fields: "gbifID"
            }
          }
        ]
      }
    end

    def file
      "citations.csv"
    end

    def write_table_rows
    end

  end

end
