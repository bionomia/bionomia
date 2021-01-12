# encoding: utf-8

module Bionomia
  class FrictionlessData

    def initialize(uuid:, output_directory:)
      @dataset = Dataset.find_by_datasetKey(uuid) rescue nil
      raise ArgumentError, 'Dataset not found' if @dataset.nil?
      @package = descriptor
      @output_dir = output_directory
      @folder = File.join(@output_dir, @dataset.datasetKey)
    end

    def create_package
      FileUtils.mkdir(@folder) unless File.exists?(@folder)

      add_resources

      #Create datapackage.json
      File.open(File.join(@folder, "datapackage.json"), 'wb') { |file| file.write(JSON.pretty_generate(@package)) }

      #Add data files
      add_data_files

      #Zip directory
      zip_file = File.join(@output_dir, "#{@dataset.datasetKey}.zip")
      FileUtils.rm zip_file, :force => true if File.file?(zip_file)
      Zip::File.open(zip_file, Zip::File::CREATE) do |zipfile|
        zipfile.add("datapackage.json", File.join(@folder, "datapackage.json"))
        zipfile.add("users.csv", File.join(@folder, "users.csv"))
        zipfile.add("occurrences.csv", File.join(@folder, "occurrences.csv"))
        zipfile.add("attributions.csv", File.join(@folder, "attributions.csv"))
      end
      FileUtils.remove_dir(@folder)
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

    def add_data_files
      users = File.open(File.join(@folder, "users.csv"), "wb")
      occurrences = File.open(File.join(@folder, "occurrences.csv"), "wb")
      attributions = File.open(File.join(@folder, "attributions.csv"), "wb")

      users_header = user_resource[:schema][:fields].map{ |u| u[:name] }
      users << CSV::Row.new(users_header, users_header, true).to_s

      occurrences_header = occurrence_resource[:schema][:fields].map{ |u| u[:name] }
      occurrences << CSV::Row.new(occurrences_header, occurrences_header, true).to_s

      attributions_header = attribution_resource[:schema][:fields].map{ |u| u[:name] }
      attributions << CSV::Row.new(attributions_header, attributions_header, true).to_s

      fields = [
        "user_occurrences.id",
        "user_occurrences.user_id",
        "user_occurrences.occurrence_id",
        "user_occurrences.action",
        "user_occurrences.visible",
        "user_occurrences.created AS claimDateTime",
        "users.id AS u_id",
        "users.given AS u_given",
        "users.family AS u_family",
        "users.date_born_precision AS u_date_born_precision",
        "users.date_died_precision AS u_date_died_precision",
        "users.date_born AS u_date_born",
        "users.date_died AS u_date_died",
        "users.other_names AS u_other_names",
        "users.wikidata AS u_wikidata",
        "users.orcid AS u_orcid",
        "claimants_user_occurrences.given AS claimantGiven",
        "claimants_user_occurrences.family AS claimantFamily",
        "claimants_user_occurrences.orcid AS claimantORCID",
      ]
      fields.concat((["gbifID"] + Occurrence.accepted_fields).map{|a| "occurrences.#{a} AS occ_#{a}"})

      gbif_ids = Set.new
      user_ids = Set.new

      @dataset.user_occurrences.select(fields).find_each(batch_size: 10_000) do |o|
        next if !o.visible

        # Add users.csv
        if !user_ids.include?(o.u_id)
          aliases = o.u_other_names.split("|").to_s if !o.u_other_names.blank?
          uri = !o.u_orcid.nil? ? "https://orcid.org/#{o.u_orcid}" : "http://www.wikidata.org/entity/#{o.u_wikidata}"
          date_born = (o.u_date_born_precision == "day") ? o.u_date_born : nil
          date_died = (o.u_date_died_precision == "day") ? o.u_date_died : nil
          data = [
            o.u_id,
            [o.u_given, o.u_family].join(" "),
            o.u_family,
            o.u_given,
            aliases,
            uri,
            o.u_orcid,
            o.u_wikidata,
            date_born,
            date_died
          ]
          users << CSV::Row.new(users_header, data).to_s
          user_ids << o.u_id
        end

        # Add attributions.csv
        uri = !o.u_orcid.nil? ? "https://orcid.org/#{o.u_orcid}" : "http://www.wikidata.org/entity/#{o.u_wikidata}"
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
        attributions << CSV::Row.new(attributions_header, data).to_s

        # Skip occurrences if already added to file
        next if gbif_ids.include?(o.occ_gbifID)

        # Add occurrences.csv
        data = o.attributes.select{|k,v| k.start_with?("occ_")}.values
        occurrences << CSV::Row.new(occurrences_header, data).to_s
        gbif_ids << o.occ_gbifID
      end

      users.close
      occurrences.close
      attributions.close
    end
  end

end
