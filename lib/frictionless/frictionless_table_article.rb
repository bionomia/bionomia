# encoding: utf-8
require_relative "frictionless_table"

module Bionomia
  class FrictionlessTableArticle < FrictionlessTable

    def initialize(**args)
      super(**args)
      @set = Set.new
    end

    def resource
      {
        name: "articles",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "id", type: "integer" },
            { name: "reference", type: "string", "skos:exactMatch": "http://schema.org/name" },
            { name: "sameAs", type: "string", format: "uri", "skos:exactMatch": "http://schema.org/sameAs" },
            { name: "datasets", type: "array", format: "uri", "skos:exactMatch": "http://schema.org/sameAs" },
          ]
        },
        primaryKey: "id"
      }
    end

    def file
      "articles.csv"
    end

    def write_table_rows
      @occurrence_files.each do |csv|
        occurrence_ids = CSV.read(csv).flatten
        occurrence_ids.in_groups_of(1_000, false).each do |group|
          Article.joins(article_occurrences: :user_occurrences)
                 .where(user_occurrences: { occurrence_id: group })
                 .where.not(user_occurrences: { action: nil })
                 .each do |article|
                   @set.add(article)
          end
        end
      end

      @set.each do |article|
        data = [
          article.id,
          article.citation,
          "https://doi.org/#{article.doi}",
          article.gbif_dois.map{|a| "https://doi.org/#{a}" }.to_s
        ]
        @csv_handle << CSV::Row.new(header, data).to_s
      end
    end

  end
end
