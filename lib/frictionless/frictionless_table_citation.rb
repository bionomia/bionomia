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
        description: "A join table between occurrence and article to permit examination of particular occurrence records that were included in a GBIF download and later used in a published article.",
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
        occurrence_ids.in_groups_of(1_000, false).each do |group|
          ArticleOccurrence.joins(:user_occurrences)
                           .where(occurrence_id: group)
                           .where(user_occurrences: { visible: true })
                           .pluck(:article_id, :occurrence_id)
            .each do |data|
              @csv_handle << CSV::Row.new(header, data).to_s
            end
        end
      end
    end

  end
end
