# encoding: utf-8

# Thanks to Michal Torma, https://github.com/MichalTorma and Rukaya Johaadien, https://github.com/rukayaj
# Who were the genesis of this idea & wrote some code during a Mobilise COST Action workshop end-January 2023 in Oslo, Norway
# See also https://github.com/bionomia/bionomia/pull/250 but closed without pulling

require_relative "frictionless_table"

module Bionomia
  class FrictionlessTableMissingAttribution < FrictionlessTable

    def initialize(**args)
      super(**args)
    end

    def resource
      {
        name: "missing-attributions",
        description: "Attributions or claims made not previously shared via dwc:recordedByID or dwc:identifiedByID.",
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
      "missing_attributions.csv"
    end

    # Note: not perfect because this checks that *both* recordedByID and identifiedByID are NULL
    def write_table_rows
      @occurrence_files.each do |csv|
        occurrence_ids = CSV.read(csv).flatten
        occurrence_ids.each_slice(2_500) do |group|
          UserOccurrence.includes(:user, :claimant, :occurrence)
                        .joins(:user, :claimant, :occurrence)
                        .where(occurrence_id: group)
                        .where.not(created_by: User::GBIF_AGENT_ID)
                        .where(visible: true)
                        .where(occurrence: { recordedByID: nil, identifiedByID: nil })
                        .each do |uo|
              uri = uo.user.uri
              identified_uri = uo.action.include?("identified") ? uri : nil
              recorded_uri = uo.action.include?("recorded") ? uri : nil
              created_name = uo.claimant.viewname
              created_uri = uo.claimant.uri
              created_date_time = uo.created.to_time.iso8601
              modified_date_time = !uo.updated.blank? ? uo.updated.to_time.iso8601 : nil

              data = [
                uo.user_id,
                uo.occurrence_id,
                identified_uri,
                recorded_uri,
                created_name,
                created_uri,
                created_date_time,
                modified_date_time
              ]
              @csv_handle << CSV::Row.new(header, data).to_s
          end
        end
      end
    end

  end

end
