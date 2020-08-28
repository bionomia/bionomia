# encoding: utf-8

module Bionomia
  class FrictionlessData

    def initialize(uuid:, output_directory:)
      @dataset = Dataset.find_by_datasetKey(uuid) rescue nil
      raise ArgumentError, 'Dataset not found' if @dataset.nil?
      @package = descriptor
      @output_dir = output_directory
    end

    def create_package
      add_resources
      dir = File.join(@output_dir, @dataset.datasetKey)
      FileUtils.mkdir(dir) unless File.exists?(dir)

      #Add datapackage.json
      File.open(File.join(dir, "datapackage.json"), 'wb') { |file| file.write(JSON.pretty_generate(@package)) }

      #Add data files
      tables = ["users", "occurrences", "attributions"]
      tables.each do |table|
        file = File.open(File.join(dir, "#{table}.csv"), "wb")
        send("#{table}_data_enum").each { |line| file << line }
        file.close
      end

      #Zip directory
      zip_file = File.join(@output_dir, "#{@dataset.datasetKey}.zip")
      FileUtils.rm zip_file, :force => true if File.file?(zip_file)
      Zip::File.open(zip_file, Zip::File::CREATE) do |zipfile|
        ["datapackage.json"].concat(tables.map{|t| "#{t}.csv"}).each do |filename|
          zipfile.add(filename, File.join(dir, filename))
        end
      end
      FileUtils.remove_dir(dir)
      GC.compact
    end

    def add_resources
      @package[:resources] << user_resource
      @package[:resources] << occurrence_resource
      @package[:resources] << attribution_resource
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
        id: "https://doi.org/#{@dataset.doi}",
        licenses: [
          {
            name: license_name,
            path: @dataset.license
          }
        ],
        profile: "tabular-data-package",
        title: "#{@dataset.title}",
        description: "#{@dataset.description}",
        datasetKey: @dataset.datasetKey,
        homepage: "https://bionomia.net/dataset/#{@dataset.datasetKey}",
        created: Time.now.to_time.iso8601,
        resources: []
      }
    end

    def user_resource
      {
        name: "users",
        path: "users.csv",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "id", type: "integer" },
            { name: "name", type: "string", rdfType: "http://schema.org/name" },
            { name: "familyName", type: "string", rdfType: "http://schema.org/familyName" },
            { name: "givenName", type: "string", rdfType: "http://schema.org/givenName" },
            { name: "alternateName", type: "array", rdfType: "http://schema.org/alternateName" },
            { name: "sameAs", type: "string", format: "uri", rdfType: "http://schema.org/sameAs" },
            { name: "orcid", type: "string" },
            { name: "wikidata", type: "string" },
            { name: "birthDate", type: "date", rdfType: "https://schema.org/birthDate" },
            { name: "deathDate", type: "date", rdfType: "https://schema.org/deathDate" }
          ]
        },
        primaryKey: "id"
      }
    end

    def occurrence_resource
      fields = [
        { name: "gbifID", type: "integer" },
        { name: "datasetKey", type: "string", format: "uuid", rdfType: "http://rs.gbif.org/terms/1.0/datasetKey" }
      ]
      accepted_fields = Occurrence.accepted_fields - ["datasetKey"]
      fields.concat(accepted_fields.map{|o| {
              name: "#{o}",
              type: "string",
              rdfType: "http://rs.tdwg.org/dwc/terms/#{o}"
            }.compact
          })
      {
        name: "occurrences",
        path: "occurrences.csv",
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

    def attribution_resource
      {
        name: "attributions",
        path: "attributions.csv",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "user_id", type: "integer" },
            { name: "occurrence_id", type: "integer" },
            { name: "identifiedBy", type: "string", format: "uri", rdfType: "http://rs.tdwg.org/dwc/iri/identifiedBy" },
            { name: "recordedBy", type: "string", format: "uri", rdfType: "http://rs.tdwg.org/dwc/iri/recordedBy" },
            { name: "attributedBy", type: "string", rdfType: "http://schema.org/name" },
            { name: "attributedByURI", type: "string", format: "uri" },
            { name: "attributionDateTime", type: "datetime", format: "any" }
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

    def users_data_enum
      Enumerator.new do |y|
        header = user_resource[:schema][:fields].map{ |u| u[:name] }
        y << CSV::Row.new(header, header, true).to_s
        @dataset.users.find_each do |u|
          aliases = u.other_names.split("|").to_s if !u.other_names.blank?
          date_born = (u.date_born_precision == "day") ? u.date_born : nil
          date_died = (u.date_died_precision == "day") ? u.date_died : nil
          data = [
            u.id,
            u.fullname,
            u.family,
            u.given,
            aliases,
            u.uri,
            u.orcid,
            u.wikidata,
            date_born,
            date_died
          ]
          y << CSV::Row.new(header, data).to_s
        end
      end
    end

    def occurrences_data_enum
      Enumerator.new do |y|
        header = occurrence_resource[:schema][:fields].map{ |u| u[:name] }
        y << CSV::Row.new(header, header, true).to_s
        gbif_ids = []
        ignored = [
          "id",
          "dateIdentified_processed",
          "eventDate_processed",
          "visible",
          "hasImage",
          "recordedByID",
          "identifiedByID"
        ]
        @dataset.claimed_occurrences.find_each(batch_size: 10_000) do |o|
          next if !o.visible || gbif_ids.include?(o.gbifID)
          gbif_ids << o.gbifID
          data = o.attributes
                  .except(*ignored)
                  .values
          y << CSV::Row.new(header, data).to_s
        end
      end
    end

    def attributions_data_enum
      attributes = [
        "user_occurrences.id",
        "user_occurrences.user_id",
        "user_occurrences.occurrence_id",
        "user_occurrences.action",
        "user_occurrences.visible",
        "user_occurrences.created AS claimDateTime",
        "users.wikidata",
        "users.orcid",
        "claimants_user_occurrences.given AS claimantGiven",
        "claimants_user_occurrences.family AS claimantFamily",
        "claimants_user_occurrences.orcid AS claimantORCID"
      ]
      Enumerator.new do |y|
        header = attribution_resource[:schema][:fields].map{ |u| u[:name] }
        y << CSV::Row.new(header, header, true).to_s
        @dataset.user_occurrences
                .select(attributes).find_each(batch_size: 10_000) do |o|
          next if !o.visible
          uri = !o.orcid.nil? ? "https://orcid.org/#{o.orcid}" : "https://www.wikidata.org/wiki/#{o.wikidata}"
          identified_uri = o.action.include?("identified") ? uri : nil
          recorded_uri = o.action.include?("recorded") ? uri : nil
          claimant_name = [o.claimantGiven, o.claimantFamily].join(" ")
          claimant_orcid = !o.claimantORCID.blank? ? "https://orcid.org/#{o.claimantORCID}" : nil
          data = [
            o.user_id,
            o.occurrence_id,
            identified_uri,
            recorded_uri,
            claimant_name,
            claimant_orcid,
            o.claimDateTime.to_time.iso8601
          ]
          y << CSV::Row.new(header, data).to_s
        end
      end
    end

  end
end
