# encoding: utf-8
require_relative "frictionless_data"

module Bionomia
  class FrictionlessDataBionomia < FrictionlessData

    def initialize(uuid:, output_directory:)
      super
    end

    #TODO: separating production of occurrences.csv and attributions.csv not efficient
    def add_data
      users = File.open(File.join(@folder, users_file), "ab")
      User.where(is_public: true).find_each do |u|
        aliases = u.other_names.split("|").to_s if !u.other_names.blank?
        data = [
          u.id,
          [u.given, u.family].join(" "),
          u.family,
          u.given,
          aliases,
          u.uri,
          u.orcid,
          u.wikidata,
          u.date_born,
          u.date_born_precision,
          u.date_died,
          u.date_died_precision
        ]
        users << CSV::Row.new(users_header, data).to_s
      end
      users.close

      occurrences = File.open(File.join(@folder, occurrences_file), "ab")
      fields = ["gbifID"] + Occurrence.accepted_fields
      gbif_ids = Set.new
      Occurrence.select(fields)
                .includes(:user_occurrences)
                .find_in_batches(batch_size: 10_000) do |batch|
        batch.each do |o|
          next if !o.user_occurrences || gbif_ids.include?(o.gbifID)
          occurrences << CSV::Row.new(occurrences_header, o.attributes.values).to_s
          gbif_ids << o.gbifID
        end
      end
      occurrences.close

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
        "users.wikidata AS u_wikidata",
        "users.orcid AS u_orcid",
        "users.is_public AS u_public",
        "claimants_user_occurrences.given AS createdGiven",
        "claimants_user_occurrences.family AS createdFamily",
        "claimants_user_occurrences.orcid AS createdORCID",
      ]
      UserOccurrence.joins(:user)
                    .joins(:claimant)
                    .select(fields)
                    .find_each(batch_size: 10_000) do |o|
        next if !o.visible || !o.u_public

        # Add attributions
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
      end
      attributions.close
    end

    def add_problem_collector_data
    end

  end

end
