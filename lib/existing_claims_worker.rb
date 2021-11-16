# encoding: utf-8

module Bionomia
  class ExistingClaimsWorker
    include Sidekiq::Worker
    sidekiq_options queue: :existing_claims, retry: 0

    def perform(row)
      recs = row["gbifIDs_recordedByID"]
                .tr('[]', '')
                .split(',')
      ids = row["gbifIDs_identifiedByID"]
                .tr('[]', '')
                .split(',')

      uniq_recs = (recs - ids).uniq
      uniq_ids = (ids - recs).uniq
      both = (recs & ids).uniq

      row["agentIDs"].split("|").map(&:strip).uniq.each do |id|
        next if id.empty?
        u = get_user(id)
        next if !u.nil? && User::BOT_IDS.include?(u.id)
        if u.nil?
          #TODO: write to a log file for id that could not be found
          next
        end
        if !uniq_recs.empty?
          uo = uniq_recs.map{|r| [u.id, r.to_i, "recorded", User::GBIF_AGENT_ID]}
          import_user_occurrences(uo)
        end
        if !uniq_ids.empty?
          uo = uniq_ids.map{|r| [u.id, r.to_i, "identified", User::GBIF_AGENT_ID]}
          import_user_occurrences(uo)
        end
        if !both.empty?
          uo = both.map{|r| [u.id, r.to_i, "recorded,identified", User::GBIF_AGENT_ID]}
          import_user_occurrences(uo)
        end
        u.flush_caches
      end
    end

    def get_user(id)
      user = nil
      if id.wiki_from_url
        user = get_wiki_user(id.wiki_from_url) rescue nil
      end
      if id.orcid_from_url && id.orcid_from_url.is_orcid?
        user = get_orcid_user(id.orcid_from_url) rescue nil
      end
      if id.viaf_from_url
        w = ::Bionomia::WikidataSearch.new
        wikidata = w.wiki_by_property('viaf', id.viaf_from_url)[:wikidata] rescue nil
        if wikidata
          user = get_wiki_user(wikidata)
        end
      end
      if id.ipni_from_url
        w = ::Bionomia::WikidataSearch.new
        wikidata = w.wiki_by_property('ipni', id.ipni_from_url)[:wikidata] rescue nil
        if wikidata
          user = get_wiki_user(wikidata)
        end
      end
      if id.bhl_from_url
        w = ::Bionomia::WikidataSearch.new
        wikidata = w.wiki_by_property('bhl', id.bhl_from_url)[:wikidata] rescue nil
        if wikidata
          user = get_wiki_user(wikidata)
        end
      end
      if id.zoobank_from_url
        w = ::Bionomia::WikidataSearch.new
        wikidata = w.wiki_by_property('zoobank', id.zoobank_from_url)[:wikidata] rescue nil
        if wikidata
          user = get_wiki_user(wikidata)
        end
      end
      if id.library_congress_from_url
        w = ::Bionomia::WikidataSearch.new
        wikidata = w.wiki_by_property('congress', id.library_congress_from_url)[:wikidata] rescue nil
        if wikidata
          user = get_wiki_user(wikidata)
        end
      end
      user
    end

    def get_orcid_user(id)
      destroyed = DestroyedUser.find_by_identifier(id)
      if !destroyed.nil? && !destroyed.redirect_to.nil?
        user = User.find_by_identifier(destroyed.redirect_to)
      else
        user = User.create_with({ orcid: id })
                   .find_or_create_by({ orcid: id })
      end
      user
    end

    def get_wiki_user(id)
      destroyed = DestroyedUser.find_by_identifier(id)
      if !destroyed.nil? && !destroyed.redirect_to.nil?
        user = User.find_by_identifier(destroyed.redirect_to)
      else
        user = User.create_with({ wikidata: id })
                   .find_or_create_by({ wikidata: id })
        if !user.valid_wikicontent?
          user.delete_search
          user.delete
          user = nil
        elsif user.valid_wikicontent? && !user.is_public?
          user.is_public = true
          user.made_public = Time.now
          user.save
        end
      end
      user
    end

    def import_user_occurrences(uo)
      qry_string = uo.map { |pair| "(#{pair[1]},#{pair[0]})" }.join(",")
      existing = UserOccurrence.where("(occurrence_id, user_id) IN (#{qry_string})")
                               .pluck(:user_id, :occurrence_id)
      uo.reject!{|k| existing.include?([k[0], k[1]])}
      UserOccurrence.import [:user_id, :occurrence_id, :action, :created_by], uo, batch_size: 1_000, validate: false, on_duplicate_key_ignore: true
    end

  end
end
