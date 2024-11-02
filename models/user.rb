class User < ActiveRecord::Base
  attr_accessor :skip_callbacks

  BOT_IDS = [1,2]

  GBIF_AGENT_ID = 2

  serialize :zenodo_access_token, JSON
  serialize :wiki_sitelinks, JSON

  has_many :user_occurrences, dependent: :delete_all
  has_many :occurrences, -> { distinct }, through: :user_occurrences, source: :occurrence
  has_many :claims, foreign_key: :created_by, class_name: "UserOccurrence", dependent: :delete_all
  has_many :claimed_occurrences, through: :claims, source: :occurrence
  has_many :user_organizations, dependent: :delete_all
  has_many :organizations, through: :user_organizations, source: :organization
  has_many :messages_received, foreign_key: :recipient_id, class_name: "Message", dependent: :delete_all
  has_many :messages_sent, class_name: "Message", foreign_key: :user_id, dependent: :delete_all
  has_many :bulk_attribution_queries_made, class_name: "BulkAttributionQuery", foreign_key: :created_by, dependent: :delete_all
  has_many :bulk_attribution_queries_received, class_name: "BulkAttributionQuery", foreign_key: :user_id, dependent: :delete_all

  before_update :set_update_time
  after_create :update_profile, :add_search, unless: :skip_callbacks
  after_update :update_search, unless: :skip_callbacks
  after_destroy :remove_search, unless: :skip_callbacks

  def self.merge_users(src_id:, dest_id:)
    return if DestroyedUser.find_by_identifier(src_id)

    src = User.default_scoped.find_by_identifier(src_id)
    dest = User.default_scoped.find_by_identifier(dest_id)
    orig_id = src.identifier.dup

    if dest.nil? && dest_id.first == "Q"
      src.orcid = nil
      src.wikidata = dest_id
      src.save
      src.reload
      src.update_profile
      src.flush_caches
    elsif !dest.nil?
      src_occurrences = src.user_occurrences.pluck(:occurrence_id)
      dest_occurrences = dest.user_occurrences.pluck(:occurrence_id) rescue []
      (src_occurrences - dest_occurrences).each_slice(2_500) do |group|
        src.user_occurrences
           .where(occurrence_id: group)
           .update_all({ user_id: dest.id })
        dest.user_occurrences
            .reload
            .where(occurrence_id: group)
            .where(created_by: src.id)
            .update_all({ created_by: dest.id })
      end
      if src.is_public?
        dest.is_public = true
        dest.save
      end
      dest.update_profile
      dest.flush_caches
      src.user_occurrences.reload.delete_all
      if ::Module::const_get("BIONOMIA")
        BIONOMIA.cache_clear("blocks/#{src_id}-stats")
      end
      src.delete
      src.delete_search
    end
    DestroyedUser.create(identifier: orig_id, redirect_to: dest_id)
  end

  def self.find_by_identifier(id)
    begin
      if id.is_orcid?
        self.find_by_orcid(id)
      elsif id.is_wiki_id?
        self.find_by_wikidata(id)
      elsif id.is_integer?
        self.find(id)
      end
    rescue
      nil
    end
  end

  def is_public?
    is_public
  end

  def is_admin?
    is_admin
  end

  def made_claim?
    visible_user_occurrences.any?
  end

  def wants_mail?
    email && wants_mail
  end

  def is_bot?
    BOT_IDS.include? id
  end

  def identifier
    orcid || wikidata || id
  end

  def uri
    if orcid
      "https://orcid.org/#{orcid}"
    elsif wikidata
      "http://www.wikidata.org/entity/#{wikidata}"
    end
  end

  def fullname
    if !family.blank?
      [given, family_part].compact.reject(&:empty?).join(' ')
    else
      orcid
    end
  end

  def fullname_reverse
    if !family.blank?
      [family_part, given].compact.reject(&:empty?).join(", ")
    else
      orcid
    end
  end

  def viewname
    label || fullname
  end

  def viewname_reverse
    fullname_reverse
  end

  def initials
    given.gsub(/([[:upper:]])[[:lower:]]+/, '\1.').gsub(/\s+/, '') rescue nil
  end

  def valid_wikicontent?
    !family.nil? && orcid.nil? &&
    (
      ( !date_died.nil? && !date_died_precision.nil? ) ||
      ( !date_born.nil? && !date_born_precision.nil? && Date.today.year - date_born.year >= 120 )
    )
  end

  def has_photo?
    !image_url.nil?
  end

  def has_recordings?
    recordings.any?
  end

  def has_identifications?
    identifications.any?
  end

  def has_specimens?
    has_recordings? || has_identifications?
  end

  def latest_attribution
    visible_user_occurrences.select("GREATEST(MAX(created), IFNULL(MAX(updated), 0)) as latest")
                            .unscope(:order)
                            .first
                            .latest
                            .to_datetime
                            .iso8601
  end

  def visible_user_occurrences
    user_occurrences.where(visible: true)
  end

  def visible_occurrences
    visible_user_occurrences.includes(:occurrence)
  end

  def hidden_occurrences_by_others
    hidden_user_occurrences.where.not(created_by: self)
                           .includes(:occurrence)
  end

  def hidden_occurrences
    hidden_user_occurrences.includes(:occurrence)
  end

  def hidden_user_occurrences
    user_occurrences.where(visible: false)
  end

  def claims_received_claimants
    claims_received.includes(:user_occurrence)
  end

  def identifications
    visible_occurrences.where(qry_identified)
  end

  def recordings
    visible_occurrences.where(qry_recorded)
  end

  def identifications_or_recordings
    visible_occurrences.where(qry_identified_or_recorded)
  end

  def identified_families
    visible_user_occurrences.where(qry_identified)
        .joins(:taxon_occurrence)
        .joins(taxon_occurrence: :taxon)
        .select("taxa.family")
        .group("taxa.family")
        .order("NULL")
        .count
        .sort_by{|_key, value| value}
        .reverse
        .to_h
  end

  def identified_families_helped
    visible_user_occurrences.where(qry_identified)
        .where.not(created_by: self)
        .joins(:taxon_occurrence)
        .joins(taxon_occurrence: :taxon)
        .select("taxa.family")
        .group("taxa.family")
        .order("NULL")
        .count
        .sort_by{|_key, value| value}
        .reverse
        .to_h
  end

  def top_family_identified
    identified_families.first[0] rescue nil
  end

  def recorded_families
    visible_user_occurrences.where(qry_recorded)
        .joins(:taxon_occurrence)
        .joins(taxon_occurrence: :taxon)
        .select("taxa.family")
        .group("taxa.family")
        .order("NULL")
        .count
        .sort_by{|_key, value| value}
        .reverse
        .to_h
  end

  def recorded_families_helped
    visible_user_occurrences.where(qry_recorded)
        .where.not(created_by: self)
        .joins(:taxon_occurrence)
        .joins(taxon_occurrence: :taxon)
        .select("taxa.family")
        .group("taxa.family")
        .order("NULL")
        .count
        .sort_by{|_key, value| value}
        .reverse
        .to_h
  end

  def top_family_recorded
    recorded_families.first[0] rescue nil
  end

  def identifications_count
    visible_user_occurrences.where(qry_identified).count
  end

  def recordings_count
    visible_user_occurrences.where(qry_recorded).count
  end

  def all_occurrences_count
    visible_user_occurrences.count
  end

  def identified_and_recorded_count
    visible_user_occurrences.where(qry_identified_and_recorded).count
  end

  def identified_or_recorded_count
    visible_user_occurrences.where(qry_identified_or_recorded).count
  end

  def qry_identified
    "user_occurrences.action IN ('identified', 'identified,recorded', 'recorded,identified')"
  end

  def qry_recorded
    "user_occurrences.action IN ('recorded', 'recorded,identified', 'identified,recorded')"
  end

  def qry_identified_and_recorded
    "user_occurrences.action IN ('recorded,identified', 'identified,recorded')"
  end

  def qry_identified_or_recorded
    "user_occurrences.action IS NOT NULL"
  end

  def recordings_with(co_collector)
    co_claims = co_collector.visible_user_occurrences
                            .select(:occurrence_id)
                            .where(co_collector.qry_recorded)
    recordings.where(occurrence_id: co_claims)
  end

  def identifications_for(collector)
    specimens = collector.visible_user_occurrences
                         .select(:occurrence_id)
                         .where(collector.qry_recorded)
    identifications.where(occurrence_id: specimens)
  end

  def identifications_by(determiner)
    determinations = determiner.visible_user_occurrences
                               .select(:occurrence_id)
                               .where(determiner.qry_identified)
    recordings.where(occurrence_id: determinations)
  end

  def claims_given
    claims.where.not(user: self).where(visible: true)
  end

  def helped_counts
    claims_given.group(:user_id)
                .order("NULL")
                .count
                .sort_by{|a,b| b}
                .reverse.to_h
  end

  def helped
    User.where(id: claims_given.select(:user_id).distinct)
  end

  def latest_helped
    claims_given.select("user_occurrences.user_id AS user_id, MAX(user_occurrences.created) AS created, COUNT(user_occurrences.user_id) AS attribution_count")
                .preload(:user)
                .group("user_occurrences.user_id")
                .order("MAX(user_occurrences.created) desc")
  end

  def claims_received
    visible_occurrences.where.not(created_by: self).order(created: :desc)
  end

  def claims_type_before_birth(type = "recordings")
    field = (type == "recordings") ? "eventDate" : "dateIdentified"
    subq = (type == "recordings") ? qry_recorded : qry_identified
    visible_occurrences.joins(:occurrence)
                       .where.not(created_by: self)
                       .where(subq)
                       .where("occurrences.#{field}_processed <= ?", date_born)
                       .order(created: :desc)
  end

  def claims_type_after_death(type = "recordings")
    field = (type == "recordings") ? "eventDate" : "dateIdentified"
    subq = (type == "recordings") ? qry_recorded : qry_identified
    visible_occurrences.joins(:occurrence)
                       .where.not(created_by: self)
                       .where(subq)
                       .where("occurrences.#{field}_processed >= ? AND occurrences.#{field}_processed <= ?", date_died, Date.today)
                       .order(created: :desc)
  end

  def claims_received_by(id)
    visible_occurrences.where({ created_by: id })
  end

  def helped_by
    subq = visible_user_occurrences.select(:created_by)
                                   .where.not(created_by: self)
                                   .distinct
    User.where(id: subq)
  end

  def helped_by_counts
    visible_user_occurrences
      .where.not(created_by: self)
      .pluck(:created_by)
      .tally
      .map{|u, total| { user: User.find(u), total: total }}
  end

  def country_counts
    identifications_or_recordings
      .references(:occurrences)
      .group("occurrences.countryCode", :action)
      .order("NULL")
      .pluck(Arel.sql("COALESCE(occurrences.countryCode, \"ZZ\")"), :action, Arel.sql("COUNT(COALESCE(occurrences.countryCode, \"ZZ\"))"))
      .each_with_object({}) do |code_action, data|
        if !data.key?(code_action[0])
          data[code_action[0]] = {
            recorded: 0,
            identified: 0
          }
        end
        if code_action[1] == "recorded" || code_action[1] == "identified"
          data[code_action[0]][code_action[1].to_sym] += code_action[2]
        else
          data[code_action[0]][:identified] += code_action[2]
          data[code_action[0]][:recorded] += code_action[2]
        end
      end
      .each_with_object({}) do |k, data|
        country = I18nData.countries(:en)[k[0]] rescue nil
        if country
          data[k[0]] = k[1].merge({ name: country })
        else
          data["OTHER"] = k[1]
        end
      end
  end

  def country_counts_helped
    identifications_or_recordings
      .where.not(created_by: self)
      .references(:occurrences)
      .group("occurrences.countryCode", :action)
      .order("NULL")
      .pluck(Arel.sql("COALESCE(occurrences.countryCode, \"ZZ\")"), :action, Arel.sql("COUNT(COALESCE(occurrences.countryCode, \"ZZ\"))"))
      .each_with_object({}) do |code_action, data|
        if !data.key?(code_action[0])
          data[code_action[0]] = {
            recorded: 0,
            identified: 0
          }
        end
        if code_action[1] == "recorded" || code_action[1] == "identified"
          data[code_action[0]][code_action[1].to_sym] += code_action[2]
        else
          data[code_action[0]][:identified] += code_action[2]
          data[code_action[0]][:recorded] += code_action[2]
        end
      end
      .each_with_object({}) do |k, data|
        country = I18nData.countries(:en)[k[0]] rescue nil
        if country
          data[k[0]] = k[1].merge({ name: country })
        else
          data["OTHER"] = k[1]
        end
      end
  end

  def quick_country_counts
    visible_user_occurrences
      .joins(:occurrence)
      .where(qry_recorded)
      .select(:countryCode)
      .distinct
      .count
  end

  def families_countries
    output = { recorded: Set.new, identified: Set.new}
    visible_user_occurrences
      .joins(:occurrence)
      .where(qry_identified_or_recorded)
      .pluck(:action, :family, :countryCode)
      .each do |a|
        if !a[1].nil?
          if a[0].include?("recorded")
            output[:recorded] << { family: a[1], country: a[2] }
          elsif a[0].include?("identified")
            output[:identified] << { family: a[1], country: a[2] }
          end
        end
      end
    output
  end

  def recorded_bins(years = 5)
    recordings = visible_user_occurrences
        .joins(:occurrence)
        .where(qry_recorded)
        .where.not(occurrences: { eventDate_processed_year: nil})
        .where("occurrences.eventDate_processed <= CURDATE()")
        .select("FLOOR(occurrences.eventDate_processed_year/#{years})*#{years} as bin", "count(*) as sum")
        .group("bin")
        .order("NULL")
        .compact
        .map{|d| [ d.bin, d.sum ] }
        .to_h
    return {} if recordings.empty?
    intervals = (recordings.min.first..recordings.max.first).step(years).map{|m| [ m, 0] }.to_h
    intervals.merge(recordings).sort.to_h
  end

  def recorded_bins_helped(years = 5)
    recordings = visible_user_occurrences
        .where.not(created_by: self)
        .joins(:occurrence)
        .where(qry_recorded)
        .where.not(occurrences: { eventDate_processed_year: nil})
        .where("occurrences.eventDate_processed <= CURDATE()")
        .select("FLOOR(occurrences.eventDate_processed_year/#{years})*#{years} as bin", "count(*) as sum")
        .group("bin")
        .order("NULL")
        .compact
        .map{|d| [ d.bin, d.sum ] }
        .to_h
    return {} if recordings.empty?
    intervals = (recordings.min.first..recordings.max.first).step(years).map{|m| [ m, 0] }.to_h
    intervals.merge(recordings).sort.to_h
  end

  def identified_bins(years = 5)
    recordings = visible_user_occurrences
        .joins(:occurrence)
        .where(qry_identified)
        .where.not(occurrences: { dateIdentified_processed_year: nil})
        .where("occurrences.dateIdentified_processed <= CURDATE()")
        .select("FLOOR(occurrences.dateIdentified_processed_year/#{years})*#{years} as bin", "count(*) as sum")
        .group("bin")
        .order("NULL")
        .compact
        .map{|d| [ d.bin, d.sum ] }
        .to_h
    return {} if recordings.empty?
    intervals = (recordings.min.first..recordings.max.first).step(years).map{|m| [ m, 0] }.to_h
    intervals.merge(recordings).sort.to_h
  end

  def identified_bins_helped(years = 5)
    recordings = visible_user_occurrences
        .where.not(created_by: self)
        .joins(:occurrence)
        .where(qry_identified)
        .where.not(occurrences: { dateIdentified_processed_year: nil})
        .where("occurrences.dateIdentified_processed <= CURDATE()")
        .select("FLOOR(occurrences.dateIdentified_processed_year/#{years})*#{years} as bin", "count(*) as sum")
        .group("bin")
        .order("NULL")
        .compact
        .map{|d| [ d.bin, d.sum ] }
        .to_h
    return {} if recordings.empty?
    intervals = (recordings.min.first..recordings.max.first).step(years).map{|m| [ m, 0] }.to_h
    intervals.merge(recordings).sort.to_h
  end

  def recorded_with
    User.joins("JOIN user_occurrences as a ON a.user_id = users.id JOIN user_occurrences b ON a.occurrence_id = b.occurrence_id")
        .where("b.user_id = ?", id)
        .where("b.action IN ('recorded','recorded,identified','identified,recorded')")
        .where("b.visible = true")
        .where("a.user_id != ?", id)
        .where("a.action IN ('recorded','recorded,identified','identified,recorded')")
        .where("a.visible = true")
        .distinct
        .order(:family)
  end

  def identified_for
    User.joins("JOIN user_occurrences as a ON a.user_id = users.id JOIN user_occurrences b ON a.occurrence_id = b.occurrence_id")
        .where("b.user_id = ?", id)
        .where("b.action IN ('identified','recorded,identified', 'identified,recorded')")
        .where("b.visible = true")
        .where("a.user_id != ?", id)
        .where("a.action IN ('recorded','recorded,identified','identified,recorded')")
        .where("a.visible = true")
        .distinct
        .order(:family)
  end

  def identified_by
    User.joins("JOIN user_occurrences as a ON a.user_id = users.id JOIN user_occurrences b ON a.occurrence_id = b.occurrence_id")
        .where("b.user_id = ?", id)
        .where("b.action IN ('recorded','recorded,identified','identified,recorded')")
        .where("b.visible = true")
        .where("a.user_id != ?", id)
        .where("a.action IN ('identified','recorded,identified','identified,recorded')")
        .where("a.visible = true")
        .distinct
        .order(:family)
  end

  def recordings_deposited_at
    recordings.pluck(:institutionCode)
              .compact
              .tally
              .sort_by {|k, v| -v}
              .to_h
  end

  def identifications_deposited_at
    identifications.pluck(:institutionCode)
                   .compact
                   .tally
                   .sort_by {|k, v| -v}
                   .to_h
  end

  def current_organization
    user_organizations.where.not(start_year: nil)
                      .where(end_year: nil)
                      .or(user_organizations.where.not(start_year: nil).where("end_year > ?", DateTime.now.year))
                      .first
                      .organization rescue nil
  end

  def latest_messages_by_senders
    messages_received
      .select(:user_id, :recipient_id, "MAX(created_at) AS maximum_created_at")
      .group(:user_id, :recipient_id)
      .order(maximum_created_at: :desc)
  end

  def messages_by_sender_count(id)
    messages_received.where({ user_id: id }).count(:all)
  end

  def messages_by_recipient(recipient_id)
    messages_sent.where({ recipient_id: recipient_id })
  end

  def bulk_claim(agent:, conditions:, ignore: false, created_by: BOT_IDS[0])
    claimed = user_occurrences.pluck(:occurrence_id)

    if conditions.blank?
      agent_recordings = agent.occurrence_agents.where(agent_role: true).pluck(:occurrence_id)
      agent_determinations = agent.occurrence_agents.where(agent_role: false).pluck(:occurrence_id)
    else
      conditions.gsub!('=>', ':')

      if !Bionomia::Validator.valid_json?(conditions)
        raise ArgumentError, "Conditions argument was not valid JSON"
      end

      conditions_hash = JSON.parse(conditions)

      conditions_hash.keys.each do |k|
        field = k.gsub(/\s+LIKE\s+\?\s*/i,"")
        if !Occurrence.accepted_fields.include?(field)
          raise ArgumentError, "Conditions field must be one of #{Occurrence.accepted_fields.join(", ")}"
        end
      end

      agent_recordings = conditions_hash.inject(agent.recordings) do |o, a|
        if a[0].include?(" ?")
          o.send("where", a)
        else
          o.send("where", Hash[[a]])
        end
      end.pluck(:gbifID)

      agent_determinations = conditions_hash.inject(agent.determinations) do |o, a|
        if a[0].include?(" ?")
          o.send("where", a)
        else
          o.send("where", Hash[[a]])
        end
      end.pluck(:gbifID)
    end

    uniq_recordings = (agent_recordings - agent_determinations) - claimed
    uniq_determinations = (agent_determinations - agent_recordings) - claimed
    both = (agent_recordings + agent_determinations) - claimed

    if ignore
      all = (agent_recordings + agent_determinations).uniq - claimed
      UserOccurrence.import all.map{|o| {
        user_id: id,
        occurrence_id: o,
        action: nil,
        visible: 0,
        created_by: created_by
      } }, batch_size: 500, validate: false, on_duplicate_key_ignore: true
    else
      UserOccurrence.import uniq_recordings.map{|o| {
        user_id: id,
        occurrence_id: o,
        action: "recorded",
        created_by: created_by
      } }, batch_size: 500, validate: false, on_duplicate_key_ignore: true

      UserOccurrence.import uniq_determinations.map{|o| {
        user_id: id,
        occurrence_id: o,
        action: "identified",
        created_by: created_by
      } }, batch_size: 500, validate: false, on_duplicate_key_ignore: true

      UserOccurrence.import both.map{|o| {
        user_id: id,
        occurrence_id: o,
        action: "recorded,identified",
        created_by: created_by
      } }, batch_size: 500, validate: false, on_duplicate_key_ignore: true
    end

    BulkAttributionQuery.create(created_by: User.find(created_by), user: self, query: conditions)
    { num_attributed: (both || all).count, ignored: ignore }
  end

  def update_profile
    self.transaction do
      UserOrganization.where({ user_id: id }).destroy_all
      if wikidata
        update_wikidata_profile
      elsif orcid
        update_orcid_profile
      end
    end
  end

  def update_orcid_profile
    orcid_lib = Bionomia::OrcidSearch.new
    data = orcid_lib.account_data(orcid)

    if data.blank?
      destroy
    else
      data[:organizations].each do |org|
        update_affiliation(org)
      end
      begin
        wikidata_lib = Bionomia::WikidataSearch.new
        wiki_data = wikidata_lib.wiki_user_by_orcid(orcid)
        if !wiki_data[:youtube_id].nil?
          data[:youtube_id] = wiki_data[:youtube_id]
        end
        if !wiki_data[:wiki_sitelinks].nil?
          data[:wiki_sitelinks] = wiki_data[:wiki_sitelinks]
        end
      rescue
      end
      update(data.except!(:organizations))
    end
  end

  def update_wikidata_profile
    wikidata_lib = Bionomia::WikidataSearch.new
    data = wikidata_lib.wiki_user_data(wikidata)
    if data && wikidata != data[:wikidata]
      User.merge_users(src_id: wikidata, dest_id: data[:wikidata])
      return
    end
    if data
      data[:organizations].each do |org|
        update_affiliation(org)
      end
      update(data.except!(:organizations).except!(:orcid))
    end
  end

  def update_affiliation(org)
    return if org[:wikidata].nil? && org[:ror].nil? && org[:grid].nil? && org[:ringgold].nil?
    return if !org[:wikidata].nil? && org[:wikidata] == org[:name]

    if !org[:ror].nil?
      organization = Organization.find_by_ror(org[:ror])
    elsif !org[:grid].nil?
      organization = Organization.find_by_grid(org[:grid])
    elsif !org[:ringgold].nil?
      organization = Organization.find_by_ringgold(org[:ringgold].to_i)
    elsif !org[:wikidata].nil?
      organization = Organization.find_by_wikidata(org[:wikidata])
    end

    if organization.nil?
      organization = Organization.create(
                       ringgold: org[:ringgold],
                       grid: org[:grid],
                       ror: org[:ror],
                       wikidata: org[:wikidata],
                       name: org[:name],
                       address: org[:address]
                     )
    end

    UserOrganization.create({
      user_id: id,
      organization_id: organization.id,
      start_year: org[:start_year],
      start_month: org[:start_month],
      start_day: org[:start_day],
      end_year: org[:end_year],
      end_month: org[:end_month],
      end_day: org[:end_day]
    })
  end

  def articles_citing_specimens
    subq = Article.joins(article_occurrences: :user_occurrences)
                  .where(user_occurrences: { user_id: id })
                  .where(user_occurrences: { visible: true })
                  .distinct
    Article.select('*').from(subq).order(created: :desc)
  end

  def cited_specimens
    visible_occurrences.joins(:article_occurrences)
  end

  def cited_specimens_by_article(article_id)
    cited_specimens.where(article_occurrences: { article_id: article_id })
  end

  def flush_caches
    return if !::Module::const_get("BIONOMIA")
    BIONOMIA.cache_clear("blocks/#{identifier}-stats")
    stats = Class.new
    stats.extend Sinatra::Bionomia::Helper::UserHelper
    BIONOMIA.cache_put_tag("blocks/#{identifier}-stats", stats.user_stats(self))
    update_search
  end

  def delete_search
    remove_search
  end

  def refresh_search
    update_search
  end

  def who_might_know
    return [] if !orcid

    es = ::Bionomia::ElasticUser.new
    doc = es.get(self)

    #Co-collectors
    users = doc["_source"]["co_collectors"].map{|a| { identifier: a["orcid"] || a["wikidata"], fullname: a["fullname"] }} rescue []

    #Identified same family
    id_family = doc["_source"]["identified"].map{|a| a["family"]}.uniq.sample rescue nil
    if id_family
      response = es.by_identified(family: id_family)
      response["hits"]["hits"].each do |a|
        next if a["_source"]["orcid"] == orcid
        users << {
          identifier: a["_source"]["wikidata"] || a["_source"]["orcid"],
          fullname: a["_source"]["fullname"]
        }
      end
    end

    #From same organization past/present
    User.uncached do
      User.joins(:user_organizations)
          .where.not(id: id)
          .where(user_organizations: { organization_id: organization_ids})
          .distinct
          .limit(10)
          .order(Arel.sql("RAND()"))
          .find_each do |u|
          users << { identifier: u.identifier, fullname: u.viewname }
      end
    end

    users.uniq.sample(5)
  end

  def collector_strings
    recordings.joins(:occurrence)
              .pluck(:recordedBy)
              .compact
              .tally
              .sort_by {|k, v| -v}
              .to_h
  end

  private

  def family_part
    [particle, family].compact.join(' ')
  end

  def set_update_time
    self.updated = Time.now
  end

  def add_search
    if !self.viewname.blank?
      es = ::Bionomia::ElasticUser.new
      es.add(self)
    end
  end

  def update_search
    if !self.viewname.blank?
      es = ::Bionomia::ElasticUser.new
      if !es.get(self)
        es.add(self)
      else
        es.update(self)
      end
    end
  end

  def remove_search
    es = ::Bionomia::ElasticUser.new
    begin
      es.delete(self)
    rescue
    end
  end

  def create_destroyed_user
    DestroyedUser.find_or_create_by({ identifier: self.identifier })
  end

end