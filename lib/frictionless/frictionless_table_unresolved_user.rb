# encoding: utf-8
require_relative "frictionless_table"

module Bionomia
  class FrictionlessTableUnresolvedUser < FrictionlessTable

    def initialize(**args)
      super(**args)
    end

    def resource
      {
        name: "users_unresolved",
        description: "Content in dwc:recordedByID that do not have a linked users, indicating that the identifier here could not be resolved against either wikidata or ORCID services.",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "occurrence_id", type: "integer" },
            { name: "recordedBy", type: "string", "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/recordedBy" },
            { name: "recordedByID", type: "string", "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/recordedByID" }
          ]
        },
        foreignKeys: [
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
      "users_unresolved.csv"
    end

    def datasetKey
      row = CSV.open(@occurrence_files.first, 'r') { |csv| csv.first }
      Occurrence.find(row[0]).datasetKey
    end

    def occurrence_files
=begin
      # Dammit this only works with the mysql2 gem; the trilogy client has no option to stream
      query = Occurrence.select(:gbifID)
                        .where(datasetKey: datasetKey)
                        .where.not(recordedByID: nil).to_sql
      db = ActiveRecord::Base.connection.instance_variable_get(:@raw_connection)
      rows = db.query(query, stream: true, cache_rows: false)
      tmp_csv = File.new(File.join(File.dirname(@csv_handle.path), "unresolved_tmp.csv"), "ab")
      CSV.open(tmp_csv.path, 'w') do |csv|
        rows.each { |row| csv << row }
      end
      tmp_csv.close
=end

      tmp_csv = File.new(File.join(File.dirname(@csv_handle.path), "unresolved_tmp.csv"), "ab")
      CSV.open(tmp_csv.path, 'w') do |csv|
        Occurrence.select(:gbifID)
          .where(datasetKey: datasetKey)
          .where.not(recordedByID: nil)
          .find_in_batches(batch_size: 10_000) do |group|
            group.each { |row| csv << [row.id] }
          end
      end
      tmp_csv.close

      system("sort -n #{tmp_csv.path} | uniq > #{tmp_csv.path}.tmp && mv #{tmp_csv.path}.tmp #{tmp_csv.path} > /dev/null 2>&1")
      system("cat #{tmp_csv.path} | parallel --pipe -N 100000 'cat > #{tmp_csv.path}-{#}.csv' > /dev/null 2>&1")
      File.unlink(tmp_csv.path)
      Dir.glob(File.dirname(tmp_csv) + "/**/#{File.basename(tmp_csv.path)}*.csv")
    end

    def write_table_rows
      occurrence_files.each do |csv|
        occurrence_ids = CSV.read(csv).flatten
        occurrence_ids.each_slice(2_500) do |group|
          Occurrence.where(id: group)
                    .where.missing(:user_occurrences)
                    .pluck(:id, :recordedBy, :recordedByID)
                    .each do |data|
            @csv_handle << CSV::Row.new(header, data).to_s
          end
        end
        File.unlink(csv)
      end
    end

  end
end
