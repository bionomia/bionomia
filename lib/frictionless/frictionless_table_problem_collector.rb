# encoding: utf-8
require_relative "frictionless_table"

module Bionomia
  class FrictionlessTableProblemCollector < FrictionlessTable

    def initialize(**args)
      super(**args)
    end

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
      @occurrence_files.each do |csv|
        occurrence_ids = CSV.read(csv).flatten
        occurrence_ids.in_groups_of(1_000, false).each do |group|
          UserOccurrence.joins(:occurrence, :user)
                        .includes(:occurrence, :user)
                        .where(visible: true)
                        .where(occurrence_id: group).each do |uo|
              next if uo.action == "identified"
              next if !uo.user.wikidata
              next if !uo.occurrence.eventDate_processed
              if ( uo.user.date_born && uo.user.date_born >= uo.occurrence.eventDate_processed ) ||
                ( uo.user.date_died && uo.user.date_died <= uo.occurrence.eventDate_processed )
                data = [
                  uo.occurrence.id,
                  uo.occurrence.catalogNumber,
                  uo.user.id,
                  uo.user.wikidata,
                  uo.user.date_born,
                  uo.user.date_born_precision,
                  uo.user.date_died,
                  uo.user.date_died_precision,
                  uo.occurrence.eventDate,
                  uo.occurrence.year
                ]
                @csv_handle << CSV::Row.new(header, data).to_s
              end
          end
        end
      end
    end

  end
end
