class User < ActiveRecord::Base

  BOT_IDS = [1,2]

  GBIF_AGENT_ID = 2

  serialize :zenodo_access_token, Hash

  has_many :user_occurrences, dependent: :delete_all
  has_many :occurrences, -> { distinct }, through: :user_occurrences, source: :occurrence
  has_many :claims, foreign_key: :created_by, class_name: "UserOccurrence", dependent: :delete_all
  has_many :claimed_occurrences, through: :claims, source: :occurrence
  has_many :user_organizations, dependent: :delete_all
  has_many :organizations, through: :user_organizations, source: :organization
  has_many :messages_received, foreign_key: :recipient_id, class_name: "Message", dependent: :delete_all
  has_many :messages_sent, class_name: "Message", foreign_key: :user_id, dependent: :delete_all

  before_update :set_update_time
  after_create :update_profile, :add_search
  after_update :update_search
  after_destroy :remove_search, :create_destroyed_user

  def self.merge_wikidata(qid, dest_qid)
    return if DestroyedUser.find_by_identifier(qid)

    DestroyedUser.create(identifier: qid, redirect_to: dest_qid)

    src = self.find_by_wikidata(qid)
    dest = self.find_by_wikidata(dest_qid)
    if dest.nil?
      src.wikidata = dest_qid
      src.save
      src.reload
      src.update_wikidata_profile
    else
      src_occurrences = src.user_occurrences.pluck(:occurrence_id)
      dest_occurrences = dest.user_occurrences.pluck(:occurrence_id) rescue []
      (src_occurrences - dest_occurrences).in_groups_of(500, false) do |group|
        src.user_occurrences.where(occurrence_id: group)
                            .update_all({ user_id: dest.id})
      end
      if src.is_public?
        dest.is_public = true
        dest.save
      end
      dest.update_wikidata_profile
      src.destroy
    end
  end

  def self.find_by_identifier(id)
    self.find_by_orcid(id) || self.find_by_wikidata(id) || self.find(id) || nil rescue nil
  end

  def is_public?
    is_public
  end

  def is_admin?
    is_admin
  end

  def made_claim?
    visible_user_occurrences.count > 0
  end

  def wants_mail?
    wants_mail
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

  def initials
    given.gsub(/([[:upper:]])[[:lower:]]+/, '\1.').gsub(/\s+/, '')
  end

  def valid_wikicontent?
    !family.nil? && orcid.nil? &&
    (
      ( !date_died.nil? && !date_died_precision.nil? ) ||
      ( !date_born.nil? && !date_born_precision.nil? && Date.today.year - date_born.year >= 120 )
    )
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
                           .order(created: :desc)
  end

  def hidden_occurrences
    hidden_user_occurrences.includes(:occurrence)
                           .order(created: :desc)
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

  def claims_given
    claims.where(visible: true).where.not(user: self)
  end

  def helped_count
    helped_ids.count
  end

  def helped_ids
    claims_given.pluck(:user_id).uniq
  end

  def helped_counts
    claims_given.group(:user_id)
                .count
                .sort_by{|a,b| b}
                .reverse.to_h
  end

  def helped
    claims_given.pluck(:user_id)
                .uniq
                .map{|u| User.find(u)}
  end

  def latest_helped
    subq = claims_given.select("user_occurrences.user_id AS user_id, MAX(user_occurrences.created) AS created, COUNT(user_occurrences.user_id) AS attribution_count")
                       .group("user_occurrences.user_id")

    claims_given.select(:user_id, :created, :attribution_count)
                .joins(:user)
                .joins("INNER JOIN (#{subq.to_sql}) sub ON sub.user_id = user_occurrences.user_id AND sub.created = user_occurrences.created")
                .preload(:user)
                .order(created: :desc)
                .distinct
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
    visible_occurrences.where({ created_by: id }).order(created: :desc)
  end

  def helped_by
    visible_user_occurrences
      .where.not(created_by: self)
      .pluck(:created_by)
      .uniq
      .map{|u| User.find(u)}
  end

  def helped_by_counts
    visible_user_occurrences
      .where.not(created_by: self)
      .pluck(:created_by)
      .inject(Hash.new(0)) { |total, e| total[e] += 1 ;total}
      .map{|u, total| { user: User.find(u), total: total }}
  end

  def country_counts
    identifications_or_recordings
      .references(:occurrences)
      .group("occurrences.countryCode", :action)
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
        country = IsoCountryCodes.find(k[0]) rescue nil
        if country
          data[k[0]] = k[1].merge({name: country.name})
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
        country = IsoCountryCodes.find(k[0]) rescue nil
        if country
          data[k[0]] = k[1].merge({name: country.name})
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

  def identified_families_countries
    visible_user_occurrences
      .joins(:occurrence)
      .where(qry_identified)
      .pluck(:family, :countryCode)
      .uniq
      .compact
      .map{|a| { family: a[0], country: a[1] }}
  end

  def recorded_families_countries
    visible_user_occurrences
      .joins(:occurrence)
      .where(qry_recorded)
      .pluck(:family, :countryCode)
      .uniq
      .compact
      .map{|a| { family: a[0], country: a[1] }}
  end

  def recorded_bins(years = 5)
    recordings = visible_user_occurrences
        .joins(:occurrence)
        .where(qry_recorded)
        .where.not(occurrences: { eventDate_processed: nil})
        .where("occurrences.eventDate_processed <= CURDATE()")
        .select("FLOOR(YEAR(occurrences.eventDate_processed)/#{years})*#{years} as bin", "count(*) as sum")
        .group("bin")
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
        .where.not(occurrences: { eventDate_processed: nil})
        .where("occurrences.eventDate_processed <= CURDATE()")
        .select("FLOOR(YEAR(occurrences.eventDate_processed)/#{years})*#{years} as bin", "count(*) as sum")
        .group("bin")
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
        .where.not(occurrences: { dateIdentified_processed: nil})
        .where("occurrences.dateIdentified_processed <= CURDATE()")
        .select("FLOOR(YEAR(occurrences.dateIdentified_processed)/#{years})*#{years} as bin", "count(*) as sum")
        .group("bin")
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
        .where.not(occurrences: { dateIdentified_processed: nil})
        .where("occurrences.dateIdentified_processed <= CURDATE()")
        .select("FLOOR(YEAR(occurrences.dateIdentified_processed)/#{years})*#{years} as bin", "count(*) as sum")
        .group("bin")
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
    codes = recordings.pluck(:institutionCode).compact
    Hash.new(0).tap{ |h| codes.each { |f| h[f] += 1 } }
               .sort_by {|_key, value| value}
               .reverse
               .to_h
  end

  def identifications_deposited_at
    codes = identifications.pluck(:institutionCode).compact
    Hash.new(0).tap{ |h| codes.each { |f| h[f] += 1 } }
               .sort_by {|_key, value| value}
               .reverse
               .to_h
  end

  def current_organization
    current = user_organizations
                .where.not(start_year: nil)
                .where(end_year: nil)
                .or(user_organizations.where.not(start_year: nil).where("end_year > ?", DateTime.now.year))
                .first
                .organization rescue nil
    if current.nil?
      current = user_organizations
                .where(end_year: nil)
                .or(user_organizations.where("end_year > ?", DateTime.now.year))
                .first
                .organization rescue nil
    end
    current
  end

  def latest_messages_by_senders
    messages_received
      .select(:user_id, :recipient_id, "MAX(created_at) AS latest")
      .group(:user_id, :recipient_id)
      .order("MAX(created_at) DESC")
  end

  def messages_by_sender_count(id)
    messages_received.where({ user_id: id }).count
  end

  def messages_by_recipient(recipient_id)
    messages_sent.where({ recipient_id: recipient_id })
  end

  def bulk_claim(agent:, conditions:, ignore: false)

    claimed = user_occurrences.pluck(:occurrence_id)

    if conditions.blank?
      agent_recordings = agent.occurrence_recorders.pluck(:occurrence_id)
      agent_determinations = agent.occurrence_determiners.pluck(:occurrence_id)
    else
      conditions.gsub!('=>', ':')

      if !Bionomia::AgentUtility.valid_json?(conditions)
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
    both = (agent_recordings & agent_determinations) - claimed

    if ignore
      all = (agent_recordings + agent_determinations).uniq - claimed
      UserOccurrence.import all.map{|o| {
        user_id: id,
        occurrence_id: o,
        action: nil,
        visible: 0,
        created_by: BOT_IDS[0]
      } }, batch_size: 500, validate: false, on_duplicate_key_ignore: true
    else
      UserOccurrence.import uniq_recordings.map{|o| {
        user_id: id,
        occurrence_id: o,
        action: "recorded",
        created_by: BOT_IDS[0]
      } }, batch_size: 500, validate: false, on_duplicate_key_ignore: true

      UserOccurrence.import uniq_determinations.map{|o| {
        user_id: id,
        occurrence_id: o,
        action: "identified",
        created_by: BOT_IDS[0]
      } }, batch_size: 500, validate: false, on_duplicate_key_ignore: true

      UserOccurrence.import both.map{|o| {
        user_id: id,
        occurrence_id: o,
        action: "recorded,identified",
        created_by: BOT_IDS[0]
      } }, batch_size: 500, validate: false, on_duplicate_key_ignore: true
    end

    { num_attributed: (both || all).count, ignored: ignore }
  end

  def update_profile
    UserOrganization.where({ user_id: id }).destroy_all
    if wikidata
      update_wikidata_profile
    elsif orcid
      update_orcid_profile
    end
  end

  def update_orcid_profile
    orcid_lib = Bionomia::OrcidSearch.new
    data = orcid_lib.account_data(orcid)
    data[:organizations].each do |org|
      update_affiliation(org)
    end
    begin
      wikidata_lib = Bionomia::WikidataSearch.new
      wiki_data = wikidata_lib.wiki_user_by_orcid(orcid)
      if !wiki_data[:twitter].nil?
        data[:twitter] = wiki_data[:twitter]
      end
    rescue
    end
    update(data.except!(:organizations))
  end

  def update_wikidata_profile
    wikidata_lib = Bionomia::WikidataSearch.new
    data = wikidata_lib.wiki_user_data(wikidata)
    if data && wikidata != data[:wikidata]
      User.merge_wikidata(wikidata, data[:wikidata])
      return
    end
    if data
      data[:organizations].each do |org|
        update_affiliation(org)
      end
      update(data.except!(:organizations))
    end
  end

  def update_affiliation(org)
    return if org[:wikidata].nil? && org[:grid].nil? && org[:ringgold].nil?

    if !org[:grid].nil?
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
                  .where(user_occurrences: { user_id: id, visible: true })
                  .distinct
    Article.select('*').from(subq).order(created: :desc)
  end

  def cited_specimens
    visible_occurrences.joins(:article_occurrences)
  end

  def cited_specimens_by_article(article_id)
    cited_specimens.where(article_occurrences: { article_id: article_id })
  end

  def cited_specimens_counts
    cited_specimens.group("article_occurrences.article_id")
                   .pluck("article_occurrences.article_id", "COUNT(article_occurrences.occurrence_id)")
  end

  def flush_caches
    return if !::Module::const_get("BIONOMIA")
    BIONOMIA.cache_clear("blocks/#{identifier}-stats")
    BIONOMIA.cache_clear("fragments/#{identifier}")
    BIONOMIA.cache_clear("fragments/#{identifier}-scribe")
  end

  def delete_search
    remove_search
  end

  private

  def family_part
    [particle, family].compact.join(' ')
  end

  def set_update_time
    self.updated = Time.now
  end

  def add_search
    if !self.family.blank?
      es = Bionomia::ElasticUser.new
      es.add(self)
    end
  end

  def update_search
    if !self.family.blank?
      es = Bionomia::ElasticUser.new
      if !es.get(self)
        es.add(self)
      else
        es.update(self)
      end
    end
  end

  def remove_search
    es = Bionomia::ElasticUser.new
    begin
      es.delete(self)
    rescue
    end
  end

  def create_destroyed_user
    DestroyedUser.find_or_create_by({ identifier: self.identifier })
  end

end
