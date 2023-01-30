# encoding: utf-8
require_relative "frictionless_data"

module Bionomia
  class FrictionlessDataDataset < FrictionlessData

    def initialize(uuid:, output_directory:)
      @dataset = Dataset.find_by_datasetKey(uuid) rescue nil
      @created = Time.now
      raise ArgumentError, 'Dataset not found' if @dataset.nil?
      super
    end

    def descriptor
      license_name = ""
      if @dataset.license.include?("/zero/1.0/")
        license_name = "public-domain-dedication"
      elsif @dataset.license.include?("/by/4.0/")
        license_name = "cc-by-4.0"
      elsif @dataset.license.include?("/by-nc/4.0/")
        license_name = "cc-by-nc-4.0"
      end

      {
        name: "bionomia-attributions",
        id: @uuid,
        licenses: [
          {
            name: license_name,
            path: @dataset.license
          }
        ],
        profile: "tabular-data-package",
        title: "ATTRIBUTIONS MADE FOR: #{@dataset.title}",
        description: "#{@dataset.description}",
        datasetKey: @dataset.datasetKey,
        homepage: "https://bionomia.net/dataset/#{@dataset.datasetKey}",
        created: @created.to_time.iso8601,
        sources: [
          {
            title: "#{@dataset.title}",
            path: "https://doi.org/#{@dataset.doi}"
          }
        ],
        keywords: [
          "specimen",
          "museum",
          "collection",
          "credit",
          "attribution",
          "bionomia"
        ],
        image: "https://bionomia.net/images/logo.png",
        resources: []
      }
    end

    def fields
      [
        "user_occurrences.id",
        "user_occurrences.user_id",
        "user_occurrences.occurrence_id",
        "user_occurrences.action",
        "user_occurrences.visible",
        "user_occurrences.created AS createdDateTime",
        "user_occurrences.updated AS modifiedDateTime",
        "users.id AS u_id",
        "users.given AS u_given",
        "users.particle AS u_particle",
        "users.family AS u_family",
        "users.date_born_precision AS u_date_born_precision",
        "users.date_died_precision AS u_date_died_precision",
        "users.date_born AS u_date_born",
        "users.date_died AS u_date_died",
        "users.other_names AS u_other_names",
        "users.wikidata AS u_wikidata",
        "users.orcid AS u_orcid",
        "claimants_user_occurrences.given AS createdGiven",
        "claimants_user_occurrences.family AS createdFamily",
        "claimants_user_occurrences.orcid AS createdORCID",
        "occurrences.eventDate_processed"
      ].concat((["gbifID"] + Occurrence.accepted_fields).map{|a| "occurrences.#{a} AS occ_#{a}"})
    end

    def add_data
      @users = File.open(File.join(@folder, users_file), "ab")
      @occurrences = File.open(File.join(@folder, occurrences_file), "ab")
      @attributions = File.open(File.join(@folder, attributions_file), "ab")
      @problems = File.open(File.join(@folder, problem_collectors_file), "ab")
      @citations = File.open(File.join(@folder, citations_file), "ab")
      @articles = File.open(File.join(@folder, articles_file), "ab")
      @missing_attributions = File.open(File.join(@folder, missing_attributions_file), "ab")


      @gbif_ids = Set.new
      @user_ids = Set.new
      @article_ids = Set.new

      if @dataset.is_large?
        query = Occurrence.select(:gbifID).where(datasetKey: @dataset.datasetKey).to_sql
        mysql2 = ActiveRecord::Base.connection.instance_variable_get(:@connection)
        rows = mysql2.query(query, stream: true, cache_rows: false)
        puts "Creating gbifID list...".yellow
        tmp_csv = File.new(File.join(@folder, "frictionless_tmp.csv"), "ab")
        tmp_csv.close
        puts "Tempfile at #{tmp_csv.path}".yellow
        CSV.open(tmp_csv.path, 'w') do |csv|
          rows.each { |row| csv << row }
        end
        #WARNING: requires GNU parallel to split CSV files
        #Hmmm...renaming the file here might mess with the unlink
        system("sort -n #{tmp_csv.path} > #{tmp_csv.path}.tmp && mv #{tmp_csv.path}.tmp #{tmp_csv.path} > /dev/null 2>&1")
        puts "Splitting files...".yellow
        system("cat #{tmp_csv.path} | parallel --pipe -N 250000 'cat > #{tmp_csv.path}-{#}.csv' > /dev/null 2>&1")
        all_files = Dir.glob(File.dirname(tmp_csv) + "/**/#{File.basename(tmp_csv.path)}*.csv")
        puts "Starting to write...".yellow
        all_files.each do |csv|
          write_to_files(CSV.read(csv).flatten)
          File.unlink(csv)
        end
        File.unlink(tmp_csv.path)
      else
        occurrence_ids = Occurrence.joins(:user_occurrences)
                            .where(datasetKey: @dataset.datasetKey)
                            .pluck("user_occurrences.id")
        write_to_files(occurrence_ids)
      end

      Article.where(id: @article_ids).find_each do |a|
        data = [
          a.id,
          a.citation,
          "https://doi.org/#{a.doi}",
          a.gbif_dois.map{|o| "https://doi.org/#{o}" }.to_s
        ]
        @articles << CSV::Row.new(articles_header, data).to_s
      end

      @users.close
      @occurrences.close
      @attributions.close
      @problems.close
      @citations.close
      @articles.close
      @missing_attributions.close
    end

    def write_to_files(occurrence_ids)
      occurrence_ids.in_groups_of(1_000, false).each do |group|
        qualifier = @dataset.is_large? ? { occurrence_id: group } : { id: group }
        @dataset.user_occurrences
                .where(user_occurrences: qualifier)
                .where(users: { is_public: true })
                .select(fields).each do |o|

          next if !o.visible

          # Add users.csv
          if !@user_ids.include?(o.u_id)
            aliases = o.u_other_names.split("|").to_s if !o.u_other_names.blank?
            uri = !o.u_orcid.nil? ? "https://orcid.org/#{o.u_orcid}" : "http://www.wikidata.org/entity/#{o.u_wikidata}"
            data = [
              o.u_id,
              [o.u_given, o.u_particle, o.u_family].compact_blank.join(" "),
              o.u_family,
              o.u_particle,
              o.u_given,
              aliases,
              uri,
              o.u_orcid,
              o.u_wikidata,
              o.u_date_born,
              o.u_date_born_precision,
              o.u_date_died,
              o.u_date_died_precision
            ]
            @users << CSV::Row.new(users_header, data).to_s
            @user_ids << o.u_id
          end

          # Add attributions.csv
          uri = !o.u_orcid.nil? ? "https://orcid.org/#{o.u_orcid}" : "http://www.wikidata.org/entity/#{o.u_wikidata}"
          identified_uri = o.action.include?("identified") ? uri : nil
          recorded_uri = o.action.include?("recorded") ? uri : nil
          created_name = [o.createdGiven, o.createdFamily].join(" ")
          created_orcid = !o.createdORCID.blank? ? "https://orcid.org/#{o.createdORCID}" : nil
          created_date_time = o.createdDateTime.to_time.iso8601
          modified_date_time = !o.modifiedDateTime.blank? ? o.modifiedDateTime.to_time.iso8601 : nil
          data = [
            o.user_id,
            o.occurrence_id,
            identified_uri,
            recorded_uri,
            created_name,
            created_orcid,
            created_date_time,
            modified_date_time
          ]
          @attributions << CSV::Row.new(attributions_header, data).to_s

          # Add problems
          if recorded_uri && o.u_wikidata && o.eventDate_processed &&
            ( o.u_date_born && o.u_date_born >= o.eventDate_processed ||
              o.u_date_died && o.u_date_died <= o.eventDate_processed )
            data = [
              o.occurrence_id,
              o.occ_catalogNumber,
              o.u_id,
              o.u_wikidata,
              o.u_date_born,
              o.u_date_born_precision,
              o.u_date_died,
              o.u_date_died_precision,
              o.occ_eventDate,
              o.occ_year
            ]
            @problems << CSV::Row.new(problems_collector_header, data).to_s
          end

          # Add missing_attributions.csv
          uri = o.u_orcid.nil? ? "http://www.wikidata.org/entity/#{o.u_wikidata}" : "https://orcid.org/#{o.u_orcid}"
          if (o.action.include?("recorded") && !o.attributes.occ_recordedByID.include?(uri)) ||
            (o.action.include?("identified") && !o.attributes.occ_identifiedByID.include?(uri))
            identified_uri = o.action.include?("identified") ? uri : nil
            recorded_uri = o.action.include?("recorded") ? uri : nil
            created_name = [o.createdGiven, o.createdFamily].join(" ")
            created_orcid = !o.createdORCID.blank? ? "https://orcid.org/#{o.createdORCID}" : nil
            created_date_time = o.createdDateTime.to_time.iso8601
            modified_date_time = !o.modifiedDateTime.blank? ? o.modifiedDateTime.to_time.iso8601 : nil
            data = [
              o.user_id,
              o.occurrence_id,
              identified_uri,
              recorded_uri,
              created_name,
              created_orcid,
              created_date_time,
              modified_date_time
            ]
            @missing_attributions << CSV::Row.new(missing_attributions_header, data).to_s
          end

          # Skip occurrences if already added to file
          next if @gbif_ids.include?(o.occ_gbifID)

          # Add occurrences.csv
          data = o.attributes.select{|k,v| k.start_with?("occ_")}.values
          @occurrences << CSV::Row.new(occurrences_header, data).to_s
          @gbif_ids << o.occ_gbifID

        end

        # Add citations and articles
        @dataset.user_occurrences
                .joins(:article_occurrences)
                .where(user_occurrences: qualifier)
                .select("article_occurrences.article_id", "user_occurrences.occurrence_id", "user_occurrences.visible")
                .distinct.each do |o|

          next if !o.visible

          data = [ o.article_id, o.occurrence_id ]
          @citations << CSV::Row.new(citations_header, data).to_s
          @article_ids << o.article_id
        end

      end
    end

    def update_frictionless_created
      @dataset.skip_callbacks = true
      @dataset.frictionless_created_at = @created
      @dataset.save
    end

  end

end
