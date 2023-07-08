# encoding: utf-8

module Bionomia
  class ExistingClaimsWorker
    include Sidekiq::Job
    sidekiq_options queue: :existing_claims, retry: 3

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

      row["agentIDs"].split("|").sort.map(&:strip).uniq.each do |id|
        next if id.empty?
        u = get_user(id)
        next if u.nil?
        next if !u.nil? && User::BOT_IDS.include?(u.id)

        # Necessary to help avoid sidekiq CPU saturation errors
        Thread.pass

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
      end
    end

    def get_user(id)
      user = nil
      wiki = ::Bionomia::WikidataSearch.new

      if id.wiki_from_url
        user = get_wiki_user(id.wiki_from_url) rescue nil
      elsif id.orcid_from_url && id.orcid_from_url.is_orcid?
        user = get_orcid_user(id.orcid_from_url) rescue nil
      elsif id.viaf_from_url
        #TODO: how to cache this & all look-ups below?
        wikidata = wiki.wiki_by_property('viaf', id.viaf_from_url)[:wikidata] rescue nil
        user = get_wiki_user(wikidata) if wikidata
      elsif id.isni_from_url
        wikidata = wiki.wiki_by_property('isni', id.isni_from_url)[:wikidata] rescue nil
        user = get_wiki_user(wikidata) if wikidata
      elsif id.ipni_from_url
        wikidata = wiki.wiki_by_property('ipni', id.ipni_from_url)[:wikidata] rescue nil
        user = get_wiki_user(wikidata) if wikidata
      elsif id.bhl_from_url
        wikidata = wiki.wiki_by_property('bhl', id.bhl_from_url)[:wikidata] rescue nil
        user = get_wiki_user(wikidata) if wikidata
      elsif id.zoobank_from_url
        wikidata = wiki.wiki_by_property('zoobank', id.zoobank_from_url)[:wikidata] rescue nil
        user = get_wiki_user(wikidata) if wikidata
      elsif id.library_congress_from_url
        wikidata = wiki.wiki_by_property('congress', id.library_congress_from_url)[:wikidata] rescue nil
        user = get_wiki_user(wikidata) if wikidata
      end
      user
    end

    def get_orcid_user(id)
      return nil if DestroyedUser.is_banned?(id)
      d = DestroyedUser.active_user_identifier(id)
      if !d.nil?
        user = User.find_by_identifier(d)
      else
        user = User.create_with({ orcid: id })
                   .find_or_create_by({ orcid: id })
      end
      user
    end

    def get_wiki_user(id)
      return nil if DestroyedUser.is_banned?(id)
      d = DestroyedUser.active_user_identifier(id)
      if !d.nil?
        user = User.find_by_identifier(d)
      else
        user = User.create_with({ wikidata: id, is_public: true, made_public: Time.now })
                   .find_or_create_by({ wikidata: id })
        if !user.valid_wikicontent?
          user.delete_search
          user.delete
          user = nil
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
