class Taxon < ActiveRecord::Base
  has_one :image, class_name: "TaxonImage", foreign_key: :family, primary_key: :family
  has_many :taxon_occurrences, dependent: :delete_all
  has_many :occurrences, through: :taxon_occurrences, source: :occurrence

  validates :family, presence: true

  KINGDOMS = [
    "Animalia",
    "Archaea",
    "Bacteria",
    "Chromista",
    "Fungi",
    "Plantae",
    "Protozoa",
    "incertae sedis"
  ]

  def self.valid_kingdom?(kingdom)
    KINGDOMS.include?(kingdom)
  end

  def has_image?
    image
  end

  def agent_recorders
    agent_ids = taxon_occurrences.joins(:occurrence_agents)
                                 .where(occurrence_agents: { agent_role: true })
                                 .select(:agent_id)
    Agent.where(id: agent_ids).distinct.order(:family, :given)
  end

  def agent_determiners
    agent_ids = taxon_occurrences.joins(:occurrence_agents)
                                 .where(occurrence_agents: { agent_role: false })
                                 .select(:agent_id)
    Agent.where(id: agent_ids).distinct.order(:family, :given)
  end

  def agents
    agent_ids = taxon_occurrences.joins(:occurrence_agents).select(:agent_id)
    Agent.where(id: agent_ids).distinct.order(:family)
  end

  #TODO: Slow query, uses temp sort
  def agent_counts
    taxon_occurrences.joins(:occurrence_agents)
                     .group(:agent_id)
                     .order(count_all: :desc)
                     .count
  end

  #TODO: Slow query, uses temp sort
  def agent_counts_unclaimed
    taxon_occurrences.joins(:occurrence_agents)
                     .left_outer_joins(:user_occurrence)
                     .where(user_occurrence: { id: nil })
                     .group(:agent_id)
                     .order(count_all: :desc)
                     .count
  end

  def timeline_recorded(start_year: 1000, end_year: Time.now.year)
    subq = UserOccurrence.select(:user_id, :eventDate_processed, :visible)
                         .joins(:occurrence, :taxon_occurrence)
                         .where(user_occurrences: { action: ['recorded', 'identified,recorded', 'recorded,identified'] })
                         .where(taxon_occurrences: { taxon_id: id })
                         .where("YEAR(eventDate_processed) BETWEEN ? AND ?", start_year, end_year)
                         .distinct

    User.select("users.*", "MIN(a.eventDate_processed) AS min_date", "MAX(a.eventDate_processed) AS max_date")
        .joins("INNER JOIN (#{subq.to_sql}) a ON a.user_id = users.id")
        .where("a.visible": true)
        .where.not("a.eventDate_processed": nil)
        .group(:id)
        .order("min_date")
  end

  def timeline_identified(start_year: 1000, end_year: Time.now.year)
    subq = UserOccurrence.select(:user_id, :dateIdentified_processed, :visible)
                         .joins(:occurrence, :taxon_occurrence)
                         .where(user_occurrences: { action: ['identified', 'identified,recorded', 'recorded,identified'] })
                         .where(taxon_occurrences: { taxon_id: id })
                         .where("YEAR(dateIdentified_processed) BETWEEN ? AND ?", start_year, end_year)
                         .distinct

    User.select("users.*", "MIN(a.dateIdentified_processed) AS min_date", "MAX(a.dateIdentified_processed) AS max_date")
        .joins("INNER JOIN (#{subq.to_sql}) a ON a.user_id = users.id")
        .where("a.visible": true)
        .where.not("a.dateIdentified_processed": nil)
        .group(:id)
        .order("min_date")
  end
end
