# encoding: utf-8
require_relative "frictionless_table"

module Bionomia
  class FrictionlessTableProblemCollector < FrictionlessTable

    def resource
      {
        name: "problem-collector-dates",
        description: "Associated occurrence records whose eventDates are earlier than a collector's birthDate or later than their deathDate.",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "occurrence_id", type: "integer" },
            { name: "catalogNumber", type: "string", "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/catalogNumber" },
            { name: "user_id", type: "integer" },
            { name: "wikidata", type: "string" },
            { name: "birthDate", type: "date", "skos:exactMatch": "https://schema.org/birthDate" },
            { name: "birthDatePrecision", type: "string", description: "Values are year, month, or day and indicate the precision of birthDate; portions of birthDate should be ignored below that of the birthDatePrecision."},
            { name: "deathDate", type: "date", "skos:exactMatch": "https://schema.org/deathDate" },
            { name: "deathDatePrecision", type: "string", description: "Values are year, month, or day and indicate the precision of deathDate; portions of deathDate should be ignored below that of the deathDatePrecision."},
            { name: "eventDate", type: "string", "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/eventDate" },
            { name: "year", type: "string", "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/year" }

          ]
        },
        foreignKeys: [
          {
            fields: "user_id",
            reference: {
              resource: "users",
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
      "problem_collector_dates.csv"
    end

    def write_table_rows
    end

  end

end
