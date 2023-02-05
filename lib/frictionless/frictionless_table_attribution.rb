# encoding: utf-8
require_relative "frictionless_table"

module Bionomia
  class FrictionlessTableAttribution < FrictionlessTable

    def resource
      {
        name: "attributions",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "user_id", type: "integer" },
            { name: "occurrence_id", type: "integer" },
            { name: "identifiedBy", type: "string", format: "uri", "skos:exactMatch": "http://rs.tdwg.org/dwc/iri/identifiedBy" },
            { name: "recordedBy", type: "string", format: "uri", "skos:exactMatch": "http://rs.tdwg.org/dwc/iri/recordedBy" },
            { name: "createdBy", type: "string", "skos:exactMatch": "http://schema.org/name" },
            { name: "createdByURI", type: "string", format: "uri" },
            { name: "createdDateTime", type: "datetime", format: "any" },
            { name: "modifiedDateTime", type: "datetime", format: "any" }
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
      "attributions.csv"
    end

    def write_table_rows
    end

  end

end
