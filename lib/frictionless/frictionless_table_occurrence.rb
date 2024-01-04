# encoding: utf-8
require_relative "frictionless_table"

module Bionomia
  class FrictionlessTableOccurrence < FrictionlessTable

    def initialize(**args)
      super(**args)
    end

    def accepted_fields
      ["gbifID"] + Occurrence.accepted_fields
    end

    def resource
      fields = accepted_fields.map do |o|
        if o == "gbifID"
          { 
            name: "gbifID",
            type: "integer"
          }
        elsif o == "datasetKey"
          { 
            name: "datasetKey",
            type: "string",
            format: "uuid",
            "skos:exactMatch": "http://rs.gbif.org/terms/1.0/datasetKey"
          }
        else
          {
            name: "#{o}",
            type: "string",
            "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/#{o}"
          }
        end
      end
      {
        name: "occurrences",
        description: "Occurrence records shared to GBIF, limited to those linked to a collector or determiner.",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: fields
        },
        primaryKey: "gbifID"
      }
    end

    def file
      "occurrences.csv"
    end

    def write_table_rows
      @occurrence_files.each do |csv|
        occurrence_ids = CSV.read(csv).flatten
        occurrence_ids.in_groups_of(1_000, false).each do |group|
          Occurrence.where(id: group).pluck(*accepted_fields).each do |data|
            @csv_handle << CSV::Row.new(header, data).to_s
          end
        end
      end
    end

  end

end
