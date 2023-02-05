# encoding: utf-8
require_relative "frictionless_table"

module Bionomia
  class FrictionlessTableUser < FrictionlessTable

    def resource
      {
        name: "users",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "id", type: "integer" },
            { name: "name", type: "string", "skos:exactMatch": "http://schema.org/name" },
            { name: "familyName", type: "string", "skos:exactMatch": "http://schema.org/familyName" },
            { name: "particle", type: "string" },
            { name: "givenName", type: "string", "skos:exactMatch": "http://schema.org/givenName" },
            { name: "alternateName", type: "array", "skos:exactMatch": "http://schema.org/alternateName" },
            { name: "sameAs", type: "string", format: "uri", "skos:exactMatch": "http://schema.org/sameAs" },
            { name: "orcid", type: "string" },
            { name: "wikidata", type: "string" },
            { name: "birthDate", type: "date", "skos:exactMatch": "https://schema.org/birthDate" },
            { name: "birthDatePrecision", type: "string", description: "Values are year, month, or day and indicate the precision of birthDate; portions of birthDate should be ignored below that of the birthDatePrecision."},
            { name: "deathDate", type: "date", "skos:exactMatch": "https://schema.org/deathDate" },
            { name: "deathDatePrecision", type: "string", description: "Values are year, month, or day and indicate the precision of deathDate; portions of deathDate should be ignored below that of the deathDatePrecision."}
          ]
        },
        primaryKey: "id"
      }
    end

    def file
      "users.csv"
    end

    def write_table_rows
=begin
      header = resource[:schema][:fields].map{ |u| u[:name] }
      user_set = Set.new
      User.joins(user_occurrences: :occurrence)
          .where(occurrences: { datasetKey: dataset.uuid })
          .find_each(batch_size: 10_000) do |user|
            user_set.add(user)
      end
      user_set.each do |user|
        aliases = user.other_names.split("|").to_s if user.other_names
        data = [
          user.id,
          user.fullname,
          user.family,
          user.particle,
          user.given,
          aliases,
          user.uri,
          user.orcid,
          user.wikidata,
          user.date_born,
          user.date_born_precision,
          user.date_died,
          user.date_died_precision
        ]
        csv_handle << CSV::Row.new(header, data).to_s
      end
=end
    end

  end

end
