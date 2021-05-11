# encoding: utf-8

module Bionomia
  class FrictionlessData

    def initialize(uuid:, output_directory:)
      @uuid = uuid
      @output_dir = output_directory
      @folder = File.join(@output_dir, @uuid)
      @package = descriptor
    end

    def descriptor
      {
        name: "bionomia-attributions",
        id: @uuid,
        licenses: [
          {
            name: "public-domain-dedication",
            path: "http://creativecommons.org/publicdomain/zero/1.0/legalcode"
          }
        ],
        profile: "tabular-data-package",
        title: "Attributions made on Bionomia",
        description: "Attributions made on Bionomia",
        datasetKey: @uuid,
        homepage: "https://bionomia.net",
        created: Time.now.to_time.iso8601,
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

    def users_file
      "users.csv"
    end

    def occurrences_file
      "occurrences.csv"
    end

    def attributions_file
      "attributions.csv"
    end

    def problem_collectors_file
      "problem_collector_dates.csv"
    end

    def user_resource
      {
        name: "users",
        path: users_file,
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
            { name: "birthDatePrecision", type: "string", description: "Values are year, month, or day and indicate the precision of birthDate; portions of birthDate should be ignored below that of the birthDatePrecision."},
            { name: "deathDate", type: "date", rdfType: "https://schema.org/deathDate" },
            { name: "deathDatePrecision", type: "string", description: "Values are year, month, or day and indicate the precision of deathDate; portions of deathDate should be ignored below that of the deathDatePrecision."}
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
        path: occurrences_file,
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
        path: attributions_file,
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
            { name: "createdBy", type: "string", rdfType: "http://schema.org/name" },
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

    def problem_collector_resource
      {
        name: "problem-collector-dates",
        path: problem_collectors_file,
        description: "Associated occurrence records whose eventDates are earlier than a collector's birthDate or later than their deathDate.",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "occurrence_id", type: "integer" },
            { name: "user_id", type: "integer" },
            { name: "wikidata", type: "string" },
            { name: "birthDate", type: "date", rdfType: "https://schema.org/birthDate" },
            { name: "birthDatePrecision", type: "string", description: "Values are year, month, or day and indicate the precision of birthDate; portions of birthDate should be ignored below that of the birthDatePrecision."},
            { name: "deathDate", type: "date", rdfType: "https://schema.org/deathDate" },
            { name: "deathDatePrecision", type: "string", description: "Values are year, month, or day and indicate the precision of deathDate; portions of deathDate should be ignored below that of the deathDatePrecision."},
            { name: "eventDate", type: "string", rdfType: "http://rs.tdwg.org/dwc/terms/eventDate" },
            { name: "year", type: "string", rdfType: "http://rs.tdwg.org/dwc/terms/year" }

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

    def create_package
      FileUtils.mkdir(@folder) unless File.exists?(@folder)

      add_resources

      #Create datapackage.json
      File.open(File.join(@folder, "datapackage.json"), 'wb') { |file| file.write(JSON.pretty_generate(@package)) }

      #Create empty data files
      create_data_files

      #Add data files
      add_data

      #Add problem file
      add_problem_collector_data

      #Zip directory
      zip_file = File.join(@output_dir, "#{@uuid}.zip")
      FileUtils.rm zip_file, :force => true if File.file?(zip_file)
      Zip::File.open(zip_file, Zip::File::CREATE) do |zipfile|
        zipfile.add("datapackage.json", File.join(@folder, "datapackage.json"))
        zipfile.add(users_file, File.join(@folder, users_file))
        zipfile.add(occurrences_file, File.join(@folder, occurrences_file))
        zipfile.add(attributions_file, File.join(@folder, attributions_file))
        zipfile.add(problem_collectors_file, File.join(@folder, problem_collectors_file))
      end
      FileUtils.remove_dir(@folder)
      GC.compact
    end

    def add_resources
      @package[:resources] << user_resource
      @package[:resources] << occurrence_resource
      @package[:resources] << attribution_resource
      @package[:resources] << problem_collector_resource
    end

    def create_data_files
      users = File.open(File.join(@folder, users_file), "wb")
      users << CSV::Row.new(users_header, users_header, true).to_s
      users.close

      occurrences = File.open(File.join(@folder, occurrences_file), "wb")
      occurrences << CSV::Row.new(occurrences_header, occurrences_header, true).to_s
      occurrences.close

      attributions = File.open(File.join(@folder, attributions_file), "wb")
      attributions << CSV::Row.new(attributions_header, attributions_header, true).to_s
      attributions.close

      problems = File.open(File.join(@folder, problem_collectors_file), "wb")
      problems << CSV::Row.new(problems_collector_header, problems_collector_header, true).to_s
      problems.close
    end

    def users_header
      user_resource[:schema][:fields].map{ |u| u[:name] }
    end

    def occurrences_header
      occurrence_resource[:schema][:fields].map{ |u| u[:name] }
    end

    def attributions_header
      attribution_resource[:schema][:fields].map{ |u| u[:name] }
    end

    def problems_collector_header
      problem_collector_resource[:schema][:fields].map{ |u| u[:name] }
    end

    def add_data
    end

    def add_problem_collector_data
    end

  end
end
