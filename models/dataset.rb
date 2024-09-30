class Dataset < ActiveRecord::Base
  attr_accessor :skip_callbacks

  has_many :occurrences, primary_key: :datasetKey, foreign_key: :datasetKey
  has_many :user_occurrences, through: :occurrences

  alias_attribute :uuid, :datasetKey

  validates :datasetKey, presence: true

  before_update :set_update_time, unless: :skip_callbacks
  after_create :add_search, unless: :skip_callbacks
  after_update :update_search, :fix_occurrences_count, unless: :skip_callbacks
  after_destroy :remove_search, unless: :skip_callbacks

  def has_claim?
    user_occurrences.where(visible: true).any?
  end

  alias_method :has_user?, :has_claim?

  def has_local_attributions?
    source_attribution_count > 0
  end

  def has_agent?
    OccurrenceAgent.select(:agent_id)
                   .joins(:occurrences)
                   .where(occurrences: { datasetKey: uuid })
                   .any?
  end

  def is_large?
    occurrences_count > 1_500_000
  end

  def refresh_search
    update_search
  end

  def users
    subq = UserOccurrence.select(:user_id, :visible)
                         .from("user_occurrences FORCE INDEX (user_occurrence_idx)")
                         .joins(:occurrence)
                         .where(occurrences: { datasetKey: uuid })
                         .distinct.to_sql
    User.joins("INNER JOIN (#{subq}) a ON a.user_id = users.id")
        .where("a.visible": true)
  end

  def users_count
    users.count
  end

  def user_ids
    users.select(:id)
  end

  def claimed_occurrences_count
    UserOccurrence.joins(:occurrence)
                  .where(occurrences: { datasetKey: uuid })
                  .unscope(:order)
                  .pluck(:gbifID, :visible)
                  .map{|a| a[0] if a[1] }.compact.uniq.count
  end

  def agents
    Agent.where(id: occurrences.select(:agent_id)
                               .joins(:occurrence_agents)
                               .group(:agent_id))
         .where.not(family: "" )
         .order(:family)
  end

  def agents_occurrence_counts
    occurrences.select(:agent_id, "COUNT(*) AS count_all")
               .joins(occurrence_agents: :agent)
               .where.not(agent: { family: "" })
               .group(:agent_id)
  end

  def agents_occurrence_unclaimed_counts
    occurrences.select(:agent_id, "COUNT(*) AS count_all")
               .joins(occurrence_agents: :agent)
               .left_outer_joins(:user_occurrences)
               .where(user_occurrences: { id: nil })
               .where.not(agent: { family: "" })
               .group(:agent_id)
  end

  def scribes
    subq = UserOccurrence.select(:created_by, :visible)
                         .from("user_occurrences FORCE INDEX (user_occurrence_idx)")
                         .joins(:occurrence)
                         .where(occurrences: { datasetKey: uuid })
                         .where.not(created_by: User::BOT_IDS)
                         .where("user_occurrences.user_id != user_occurrences.created_by")
                         .distinct.to_sql
    User.joins("INNER JOIN (#{subq}) a ON a.created_by = users.id")
        .where("a.visible": true)
  end

  def license_icon(form = "button")
    return if license.nil?
    size = (form == "button") ? "88x31" : "80x15"
    if license.include?("/zero/")
      url = "https://i.creativecommons.org/p/zero/1.0/#{size}.png"
    elsif license.include?("/by/")
      url = "https://i.creativecommons.org/l/by/4.0/#{size}.png"
    elsif license.include?("/by-nc/")
      url = "https://i.creativecommons.org/l/by-nc/4.0/#{size}.png"
    else
      url = "/images/Clear1x1.gif"
    end
    url
  end

  def institution_codes
    occurrences.pluck(:institutionCode).compact.uniq.sort
  end

  def collection_codes
    occurrences.pluck(:collectionCode).compact.uniq.sort
  end

  def top_institution_codes
    occurrences.limit(1_500_000).pluck(:institutionCode)
               .compact
               .tally
               .sort_by{|k,v| -v}
               .first(4)
               .to_h
               .keys rescue []
  end

  def top_collection_codes
    occurrences.limit(1_500_000).pluck(:collectionCode)
               .compact
               .tally
               .sort_by{|k,v| -v}
               .first(4)
               .to_h
               .keys rescue []
  end

  def collected_before_birth_after_death
    user_occurrences.joins(:user)
                    .where(action: ["recorded", "recorded,identified", "identified,recorded"])
                    .where("users.date_born >= occurrences.eventDate_processed OR users.date_died <= occurrences.eventDate_processed")
  end

  def current_occurrences_count
    begin
      response = RestClient::Request.execute(
        method: :get,
        url: "https://api.gbif.org/v1/occurrence/search?dataset_key=#{uuid}&limit=0"
      )
      response = JSON.parse(response, symbolize_names: true)
      response[:count].to_i
    rescue
      0
    end
  end

  def timeline_recorded(start_year: 1000, end_year: Time.now.year)
    subq = UserOccurrence.from("user_occurrences FORCE INDEX (user_occurrence_idx)")
                         .select(:user_id, :eventDate_processed, :eventDate_processed_year, :visible)
                         .joins(:occurrence)
                         .where(user_occurrences: { action: ['recorded', 'identified,recorded', 'recorded,identified'] })
                         .where(occurrences: { datasetKey: uuid })
                         .where("eventDate_processed_year BETWEEN ? AND ?", start_year, end_year)
                         .distinct

    User.select("users.*", "MIN(a.eventDate_processed) AS min_date", "MAX(a.eventDate_processed) AS max_date")
        .joins("INNER JOIN (#{subq.to_sql}) a ON a.user_id = users.id")
        .where("a.visible": true)
        .where.not("a.eventDate_processed_year": nil)
        .group(:id)
        .order("min_date")
  end

  def timeline_identified(start_year: 1000, end_year: Time.now.year)
    subq = UserOccurrence.from("user_occurrences FORCE INDEX (user_occurrence_idx)")
                         .select(:user_id, :dateIdentified_processed, :dateIdentified_processed_year, :visible)
                         .joins(:occurrence)
                         .where(user_occurrences: { action: ['identified', 'identified,recorded', 'recorded,identified'] })
                         .where(occurrences: { datasetKey: uuid })
                         .where("dateIdentified_processed_year BETWEEN ? AND ?", start_year, end_year)
                         .distinct

    User.select("users.*", "MIN(a.dateIdentified_processed) AS min_date", "MAX(a.dateIdentified_processed) AS max_date")
        .joins("INNER JOIN (#{subq.to_sql}) a ON a.user_id = users.id")
        .where("a.visible": true)
        .where.not("a.dateIdentified_processed_year": nil)
        .group(:id)
        .order("min_date")
  end

  def article_occurrences
    ArticleOccurrence.select(:id, :article_id, :occurrence_id)
                     .where(occurrence_id: user_occurrences.select(:occurrence_id).where(visible: true ))
                     .distinct
  end

  private

  def set_update_time
    self.updated_at = Time.now
  end

  def add_search
    es = Bionomia::ElasticDataset.new
    if !es.get(self)
      es.add(self)
    end
  end

  def update_search
    es = Bionomia::ElasticDataset.new
    if !es.get(self)
      es.add(self)
    else
      es.update(self)
    end
  end

  def remove_search
    es = Bionomia::ElasticDataset.new
    begin
      es.delete(self)
    rescue
    end
  end

  def fix_occurrences_count
    Occurrence.counter_culture_fix_counts only: :dataset, where: { datasetKey: uuid }
  end

end
