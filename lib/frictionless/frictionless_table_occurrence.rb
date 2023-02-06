# encoding: utf-8
require_relative "frictionless_table"

module Bionomia
  class FrictionlessTableOccurrence < FrictionlessTable

    def initialize(**args)
      super(**args)
    end

    def resource
      accepted_fields = ["gbifID"] + Occurrence.accepted_fields
      fields = accepted_fields.map do |o|
        if o == "gbifID"
          { name: "gbifID", type: "integer" }
        elsif o == "datasetKey"
          { name: "datasetKey", type: "string", format: "uuid", "skos:exactMatch": "http://rs.gbif.org/terms/1.0/datasetKey" }
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
      accepted_fields = ["gbifID"] + Occurrence.accepted_fields
      @occurrence_files.each do |csv|
        occurrence_ids = CSV.read(csv).flatten
        occurrence_ids.in_groups_of(5_000, false).each do |group|
          Occurrence.where(id: group).each do |o|
            data = o.attributes
                    .select{|k,v| accepted_fields.include?(k) }
                    .values
            @csv_handle << CSV::Row.new(header, data).to_s
          end
        end
      end
    end

  end

end
