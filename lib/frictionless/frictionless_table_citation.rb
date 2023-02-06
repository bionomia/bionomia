# encoding: utf-8
require_relative "frictionless_table"

module Bionomia
  class FrictionlessTableCitation < FrictionlessTable

    def initialize(**args)
      super(**args)
    end

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
      @occurrence_files.each do |csv|
        occurrence_ids = CSV.read(csv).flatten
        occurrence_ids.in_groups_of(5_000, false).each do |group|
          ArticleOccurrence.where(occurrence_id: group)
            .each do |ao|
              data = [ ao.article_id, ao.occurrence_id ]
              @csv_handle << CSV::Row.new(header, data).to_s
            end
        end
      end
    end

  end
end
