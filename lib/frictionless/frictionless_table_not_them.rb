# encoding: utf-8
require_relative "frictionless_table"

module Bionomia
  class FrictionlessTableNotThem < FrictionlessTable

    def initialize(**args)
      super(**args)
    end

    def resource
      {
        name: "unascribed",
        description: "Negative assertions made alongside the provenance, which may help inform local disambiguation activities.",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "occurrence_id", type: "integer" },
            { name: "catalogNumber", type: "string", "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/catalogNumber" },
            { name: "recordedBy", type: "string", "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/recordedeBy" },
            { name: "recordedByID", type: "string", "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/recordedByID" },
            { name: "identifiedBy", type: "string", "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/identifiedBy" },
            { name: "identifiedByID", type: "string", "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/identifiedByID" },
            { name: "differentFrom", type: "string", "skos:exactMatch": "http://www.w3.org/2002/07/owl#differentFrom" },
            { name: "user_id", type: "integer" },
            { name: "name", type: "string", "skos:exactMatch": "http://schema.org/name" },
            { name: "wikidata", type: "string" },
            { name: "orcid", type: "string" },
            { name: "createdBy", type: "string", "skos:exactMatch": "http://schema.org/name" },
            { name: "createdByURI", type: "string", format: "uri" },
            { name: "createdDateTime", type: "datetime", format: "any" },
            { name: "modifiedDateTime", type: "datetime", format: "any" }
          ]
        },
        foreignKeys: [
         {
            fields: "occurrence_id",
            reference: {
              resource: "occurrences",
              fields: "gbifID"
            }
          },
         {
           fields: "user_id",
           reference: {
             resource: "users",
             fields: "id"
           }
         }
       ]
      }
    end

    def file
      "not_them_assertions.csv"
    end

    def datasetKey
      begin
        row = CSV.open(@occurrence_files.first, 'r') { |csv| csv.first }
        Occurrence.find(row[0]).datasetKey
      rescue
        nil
      end
    end

    def occurrence_files
      #Note: use full user_occurrences hash in where clause because of a bug in ActiveRecord
      return [] if !datasetKey
      query = UserOccurrence.select(:occurrence_id)
                            .joins(:occurrence)
                            .where(occurrence: { datasetKey: datasetKey })
                            .where(user_occurrences: { visible: false })
                            .to_sql
      mysql2 = ActiveRecord::Base.connection.instance_variable_get(:@connection)
      rows = mysql2.query(query, stream: true, cache_rows: false)
      tmp_csv = File.new(File.join(File.dirname(@csv_handle.path), "mismatch_tmp.csv"), "ab")
      CSV.open(tmp_csv.path, 'w') do |csv|
        rows.each { |row| csv << row }
      end
      tmp_csv.close
      system("sort -n #{tmp_csv.path} | uniq > #{tmp_csv.path}.tmp && mv #{tmp_csv.path}.tmp #{tmp_csv.path} > /dev/null 2>&1")
      system("cat #{tmp_csv.path} | parallel --pipe -N 10000 'cat > #{tmp_csv.path}-{#}.csv' > /dev/null 2>&1")
      File.unlink(tmp_csv.path)
      Dir.glob(File.dirname(tmp_csv) + "/**/#{File.basename(tmp_csv.path)}*.csv")
    end

    def write_table_rows
      occurrence_files.each do |csv|
         occurrence_ids = CSV.read(csv).flatten
         occurrence_ids.each_slice(2_500) do |group|
            UserOccurrence.joins(:occurrence, :user, :claimant)
                          .includes(:occurrence, :user, :claimant)
                          .where(occurrence_id: group)
                          .where(visible: false).each do |uo|

               modified_date_time = !uo.updated.blank? ? uo.updated.to_time.iso8601 : nil
               data = [
                  uo.occurrence_id,
                  uo.occurrence.catalogNumber,
                  uo.occurrence.recordedBy,
                  uo.occurrence.recordedByID,
                  uo.occurrence.identifiedBy,
                  uo.occurrence.identifiedByID,
                  uo.user.uri,
                  uo.user.id,
                  uo.user.viewname,
                  uo.user.wikidata,
                  uo.user.orcid,
                  uo.claimant.viewname,
                  uo.claimant.uri,
                  uo.created.to_time.iso8601,
                  modified_date_time
               ]
               @csv_handle << CSV::Row.new(header, data).to_s
           end
         end
         File.unlink(csv)
      end
    end

  end

end
