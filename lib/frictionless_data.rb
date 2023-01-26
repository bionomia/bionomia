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
        image: "https://bionomia.net/images/logo.png"
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

    def citations_file
      "citations.csv"
    end

    def articles_file
      "articles.csv"
    end

    def users_resource_size
      File.size(File.join(@folder, users_file + ".zip")) rescue nil
    end

    def occurrences_resource_size
      File.size(File.join(@folder, occurrences_file + ".zip")) rescue nil
    end

    def attributions_resource_size
      File.size(File.join(@folder, attributions_file + ".zip")) rescue nil
    end

    def problem_collectors_resource_size
      File.size(File.join(@folder, problem_collectors_file + ".zip")) rescue nil
    end

    def citations_resource_size
      File.size(File.join(@folder, citations_file + ".zip")) rescue nil
    end

    def articles_resource_size
      File.size(File.join(@folder, articles_file + ".zip")) rescue nil
    end

    def user_resource
      {
        name: "users",
        path: "https://bionomia.net/dataset/#{@uuid}/#{users_file}.zip",
        format: "csv",
        compression: "zip",
        mediatype: "text/csv",
        encoding: "utf-8",
        bytes: users_resource_size,
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "id", type: "integer" },
            { name: "name", type: "string", "skos:exactMatch": "http://schema.org/name" },
            { name: "familyName", type: "string", "skos:exactMatch": "http://schema.org/familyName" },
            { name: "particle", type: "string" },
            { name: "givenName", type: "string", "skos:exactMatch": "http://schema.org/givenName" },
            { name: "alternateName", type: "array", "skos:exactMatch": "http://schema.org/alternateName" },
            { name: "sameAs", type: "string", format: "uri", "skos:exactMatch": "http://schema.org/sameAs" },
            { name: "orcid", type: "string" },
            { name: "wikidata", type: "string" },
            { name: "birthDate", type: "date", "skos:exactMatch": "https://schema.org/birthDate" },
            { name: "birthDatePrecision", type: "string", description: "Values are year, month, or day and indicate the precision of birthDate; portions of birthDate should be ignored below that of the birthDatePrecision."},
            { name: "deathDate", type: "date", "skos:exactMatch": "https://schema.org/deathDate" },
            { name: "deathDatePrecision", type: "string", description: "Values are year, month, or day and indicate the precision of deathDate; portions of deathDate should be ignored below that of the deathDatePrecision."}
          ]
        },
        primaryKey: "id"
      }
    end

    def occurrence_resource
      fields = [
        { name: "gbifID", type: "integer" },
        { name: "datasetKey", type: "string", format: "uuid", "skos:exactMatch": "http://rs.gbif.org/terms/1.0/datasetKey" }
      ]
      accepted_fields = Occurrence.accepted_fields - ["datasetKey"]
      fields.concat(accepted_fields.map{|o| {
              name: "#{o}",
              type: "string",
              "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/#{o}"
            }.compact
          })
      {
        name: "occurrences",
        path: "https://bionomia.net/dataset/#{@uuid}/#{occurrences_file}.zip",
        format: "csv",
        compression: "zip",
        mediatype: "text/csv",
        encoding: "utf-8",
        bytes: occurrences_resource_size,
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
        path: "https://bionomia.net/dataset/#{@uuid}/#{attributions_file}.zip",
        format: "csv",
        compression: "zip",
        mediatype: "text/csv",
        encoding: "utf-8",
        bytes: attributions_resource_size,
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

    def problem_collector_resource
      {
        name: "problem-collector-dates",
        path: "https://bionomia.net/dataset/#{@uuid}/#{problem_collectors_file}.zip",
        description: "Associated occurrence records whose eventDates are earlier than a collector's birthDate or later than their deathDate.",
        format: "csv",
        compression: "zip",
        mediatype: "text/csv",
        encoding: "utf-8",
        bytes: problem_collectors_resource_size,
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "occurrence_id", type: "integer" },
            { name: "catalogNumber", type: "string", "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/catalogNumber" },
            { name: "user_id", type: "integer" },
            { name: "wikidata", type: "string" },
            { name: "birthDate", type: "date", "skos:exactMatch": "https://schema.org/birthDate" },
            { name: "birthDatePrecision", type: "string", description: "Values are year, month, or day and indicate the precision of birthDate; portions of birthDate should be ignored below that of the birthDatePrecision."},
            { name: "deathDate", type: "date", "skos:exactMatch": "https://schema.org/deathDate" },
            { name: "deathDatePrecision", type: "string", description: "Values are year, month, or day and indicate the precision of deathDate; portions of deathDate should be ignored below that of the deathDatePrecision."},
            { name: "eventDate", type: "string", "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/eventDate" },
            { name: "year", type: "string", "skos:exactMatch": "http://rs.tdwg.org/dwc/terms/year" }

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

    def citation_resource
      {
        name: "article-occurrences",
        path: "https://bionomia.net/dataset/#{@uuid}/#{citations_file}.zip",
        description: "Citations of articles",
        format: "csv",
        compression: "zip",
        mediatype: "text/csv",
        encoding: "utf-8",
        bytes: citations_resource_size,
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "article_id", type: "integer" },
            { name: "occurrence_id", type: "integer" }
          ]
        },
        foreignKeys: [
          {
            fields: "article_id",
            reference: {
              resource: "articles",
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

    def article_resource
      {
        name: "articles",
        path: "https://bionomia.net/dataset/#{@uuid}/#{articles_file}.zip",
        format: "csv",
        compression: "zip",
        mediatype: "text/csv",
        encoding: "utf-8",
        bytes: articles_resource_size,
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "id", type: "integer" },
            { name: "reference", type: "string", "skos:exactMatch": "http://schema.org/name" },
            { name: "sameAs", type: "string", format: "uri", "skos:exactMatch": "http://schema.org/sameAs" },
            { name: "datasets", type: "array", format: "uri", "skos:exactMatch": "http://schema.org/sameAs" },
          ]
        },
        primaryKey: "id"
      }
    end

    def create_package
      FileUtils.mkdir(@folder) unless File.exists?(@folder)

      flush_existing

      add_resources

      #Create empty data files
      create_data_files

      #Add data files
      add_data

      #Zip each file in place
      Dir.foreach(@folder) do |f|
        fn = File.join(@folder, f)
        next if File.extname(fn) != ".csv"
        next if File.basename(fn, ".csv")[0,12] == "frictionless"
        Zip::File.open(fn + ".zip", Zip::File::CREATE) do |zipfile|
          zipfile.add(File.basename(fn), File.join(@folder, File.basename(fn)))
        end
        File.delete(fn)
      end

      # Add resources again to capture file sizes
      add_resources

      #Create datapackage.json
      File.open(File.join(@folder, "datapackage.json"), 'wb') { |file| file.write(JSON.pretty_generate(@package)) }
    end

    def flush_existing
      Dir.foreach(@folder) do |f|
        fn = File.join(@folder, f)
        File.delete(fn) if f != '.' && f != '..'
      end
    end

    def add_resources
      @package[:resources] = []
      @package[:resources] << user_resource
      @package[:resources] << occurrence_resource
      @package[:resources] << attribution_resource
      @package[:resources] << problem_collector_resource
      @package[:resources] << citation_resource
      @package[:resources] << article_resource
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

      citations = File.open(File.join(@folder, citations_file), "wb")
      citations << CSV::Row.new(citations_header, citations_header, true).to_s
      citations.close

      articles = File.open(File.join(@folder, articles_file), "wb")
      articles << CSV::Row.new(articles_header, articles_header, true).to_s
      articles.close
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

    def citations_header
      citation_resource[:schema][:fields].map{ |u| u[:name] }
    end

    def articles_header
      article_resource[:schema][:fields].map{ |u| u[:name] }
    end

    def add_data
    end

  end
end
