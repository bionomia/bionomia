# encoding: utf-8

module Bionomia
  class ZenodoDownloadWorker
    include Sidekiq::Job
    sidekiq_options queue: :default, retry: 1

    def perform
      @directory = File.join(BIONOMIA.settings.root, BIONOMIA.settings.public_folder, "data")
      return if !Dir.exist?(@directory) || Dir.empty?(@directory)

      @z = Bionomia::ZenodoDownload.new(resource: nil)

      @doi = KeyValue.get('zenodo_doi')
      if @doi
        submit_update
      else
        submit_new
      end
    end

    def submit_new
      # Create the files
      csv = make_csv
      gzip = make_gzip

      begin
        doi_id = @z.new_deposit
        id = doi_id[:recid]

        # PUT the files & publish
        Thread.pass
        @z.add_file(file_path: csv)

        Thread.pass
        @z.add_file(file_path: gzip)

        pub = @z.publish(id: id)
      
        KeyValue.set("zenodo_doi", "https://doi.org/#{pub[:doi]}")
        KeyValue.set("zenodo_concept_doi", "https://doi.org/#{pub[:conceptdoi]}")
        puts "Created".green
      rescue
        @z.delete_draft(id: id) if id
        puts "Token failed".red
      end
    end

    def submit_update
      # Create the files
      csv = make_csv
      gzip = make_gzip

      begin
        old_id = @doi.split(".").last
        doi_id = @z.new_version(id: old_id)
    
        # DELETE existing files
        id = doi_id[:recid]
        files = @z.list_files(id: id).map{|f| f[:id]}
        files.each do |file_id|
          @z.delete_file(id: id, file_id: file_id)
        end

        # PUT the files & publish
        Thread.pass
        @z.add_file(file_path: csv)

        Thread.pass
        @z.add_file(file_path: gzip)

        pub = @z.publish(id: id)
    
        if pub[:doi].nil?
          @z.delete_draft(id: id)
        else
          KeyValue.set("zenodo_doi", "https://doi.org/#{pub[:doi]}")
        end
      rescue
        @z.delete_draft(id: id) if id
      end

    end

    private

    def make_gzip
      csv_file = File.join(@directory, "bionomia-public-claims.csv")
      query = UserOccurrence.joins(:user)
                          .select(:occurrence_id, :action, :wikidata, :orcid)
                          .where(user_occurrences: { visible: true })
                          .where(users: {is_public: true })
                          .to_sql
      mysql2 = ActiveRecord::Base.connection.instance_variable_get(:@connection)
      rows = mysql2.query(query, stream: true, cache_rows: false)
      CSV.open(csv_file, 'w') do |csv|
        csv << ["Subject", "Predicate", "Object"]
        rows.each do |row|
          if row[2]
            user = "http://www.wikidata.org/entity/#{row[2]}"
          elsif row[3]
            user = "https://orcid.org/#{row[3]}"
          end
          row[1].split(",").each do |item|
            if item.strip == "recorded"
              action = "http://rs.tdwg.org/dwc/iri/recordedBy"
            elsif item.strip == "identified"
              action = "http://rs.tdwg.org/dwc/iri/identifiedBy"
            end
            csv << ["https://gbif.org/occurrence/#{row[0]}", action, user]
          end
        end
      end

      gzip_file = File.join(@directory, "#{File.basename(csv_file, ".csv")}.csv.gz")
      Zlib::GzipWriter.open(gzip_file) do |gz|
        gz.mtime = File.mtime(csv_file)
        gz.orig_name = csv_file
        File.open(csv_file) do |file|
          while chunk = file.read(16*1024) do
            gz.write(chunk)
          end
        end
      end
      File.delete(csv_file)
      gzip_file
    end

    def make_csv
      csv_file = File.join(@directory, "bionomia-public-profiles.csv")
      users = User.where(is_public: true)
      CSV.open(csv_file, 'w') do |csv|
        csv << ["Family", "Given", "Particle", "OtherNames", "LabelName", "Country", "Keywords", "wikidata", "ORCID", "URL"]
        users.find_each do |u|
          csv << [
            u.family,
            u.given,
            u.particle,
            u.other_names,
            u.label,
            u.country,
            u.keywords,
            u.wikidata,
            u.orcid,
            "https://bionomia.net/" + u.identifier
          ]
        end
      end
      csv_file
    end

  end
end