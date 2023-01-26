# encoding: utf-8
require_relative "frictionless_data"

module Bionomia
  class FrictionlessDataBionomia < FrictionlessData

    def initialize(uuid:, output_directory:)
      super
    end

    def add_data
      users = File.open(File.join(@folder, users_file), "ab")
      occurrences = File.open(File.join(@folder, occurrences_file), "ab")
      attributions = File.open(File.join(@folder, attributions_file), "ab")

      fields = [
        "user_occurrences.id",
        "user_occurrences.user_id",
        "user_occurrences.occurrence_id",
        "user_occurrences.action",
        "user_occurrences.visible",
        "user_occurrences.created AS createdDateTime",
        "user_occurrences.updated AS modifiedDateTime",
        "users.id AS u_id",
        "users.given AS u_given",
        "users.family AS u_family",
        "users.particle AS u_particle",
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
      ]
      fields.concat((["gbifID"] + Occurrence.accepted_fields).map{|a| "occurrences.#{a} AS occ_#{a}"})

      gbif_ids = Set.new
      user_ids = Set.new

      UserOccurrence.joins(:user)
        .where(users: { is_public: true })
        .or(UserOccurrence.joins(:user).where.not(users: { wikidata: nil }))
        .joins(:claimant)
        .joins(:occurrence)
        .select(fields).find_in_batches(batch_size: 25_000) do |batch|
        batch.each do |o|
          next if !o.visible

          # Add users.csv
          if !user_ids.include?(o.u_id)
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
            users << CSV::Row.new(users_header, data).to_s
            user_ids << o.u_id
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
          attributions << CSV::Row.new(attributions_header, data).to_s

          # Skip occurrences if already added to file
          next if gbif_ids.include?(o.occ_gbifID)

          # Add occurrences.csv
          data = o.attributes.select{|k,v| k.start_with?("occ_")}.values
          occurrences << CSV::Row.new(occurrences_header, data).to_s
          gbif_ids << o.occ_gbifID
        end
      end

      users.close
      occurrences.close
      attributions.close
    end

    def add_problem_collector_data
    end

    def add_citation_data
    end

  end

end
