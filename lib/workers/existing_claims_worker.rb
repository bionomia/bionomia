# encoding: utf-8

module Bionomia
  class ExistingClaimsWorker
    include Sidekiq::Job
    sidekiq_options queue: :existing_claims, retry: 3

    def perform(row)
      id = row["user_id"]

      return if id.blank?

      source_user = SourceUser.find(id)
      u = get_user(source_user.identifier)

      return if u.nil?
      return if !u.nil? && User::BOT_IDS.include?(u.id)

      recordings = source_user.recordings.pluck(:occurrence_id).uniq
      identifications = source_user.identifications.pluck(:occurrence_id).uniq

      uniq_recs = (recordings - identifications).uniq
      uniq_ids = (identifications - recordings).uniq
      both = (recordings & identifications).uniq

      if !uniq_recs.empty?
        uo = uniq_recs.map{|r| [u.id, r.to_i, "recorded", User::GBIF_AGENT_ID]}
        uo.each_slice(2_500) do |group|
          UserOccurrence.import [:user_id, :occurrence_id, :action, :created_by], group, validate: false, on_duplicate_key_ignore: true
        end
      end
      if !uniq_ids.empty?
        uo = uniq_ids.map{|r| [u.id, r.to_i, "identified", User::GBIF_AGENT_ID]}
        uo.each_slice(2_500) do |group|
          UserOccurrence.import [:user_id, :occurrence_id, :action, :created_by], group, validate: false, on_duplicate_key_ignore: true
        end
      end
      if !both.empty?
        uo = both.map{|r| [u.id, r.to_i, "recorded,identified", User::GBIF_AGENT_ID]}
        uo.each_slice do |group|
          UserOccurrence.import [:user_id, :occurrence_id, :action, :created_by], group, validate: false, on_duplicate_key_ignore: true
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

  end
end
