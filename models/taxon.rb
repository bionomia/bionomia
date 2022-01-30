class Taxon < ActiveRecord::Base
  has_many :taxon_occurrences, dependent: :delete_all
  has_many :occurrences, through: :taxon_occurrences, source: :occurrence
  has_one :image, class_name: "TaxonImage", foreign_key: :family, primary_key: :family

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
    Agent.joins(:occurrence_recorders)
         .joins("INNER JOIN taxon_occurrences ON occurrence_recorders.occurrence_id = taxon_occurrences.occurrence_id")
         .where(taxon_occurrences: { taxon_id: id })
         .distinct
         .order(:family, :given)
  end

  def agent_determiners
    Agent.joins(:occurrence_determiners)
         .joins("INNER JOIN taxon_occurrences ON occurrence_determiners.occurrence_id = taxon_occurrences.occurrence_id")
         .where(taxon_occurrences: { taxon_id: id })
         .distinct
         .order(:family, :given)
  end

  def occurrence_determiners_union_recorders
    determiners = OccurrenceDeterminer
                    .select(:agent_id, :occurrence_id)
                    .joins("INNER JOIN taxon_occurrences ON occurrence_determiners.occurrence_id = taxon_occurrences.occurrence_id")
                    .where(taxon_occurrences: { taxon_id: id })
    recorders = OccurrenceRecorder
                    .select(:agent_id, :occurrence_id)
                    .joins("INNER JOIN taxon_occurrences ON occurrence_recorders.occurrence_id = taxon_occurrences.occurrence_id")
                    .where(taxon_occurrences: { taxon_id: id })
    recorders.union(determiners).unscope(:order)
  end

  def agents
    combined = occurrence_determiners_union_recorders
                .select(:agent_id)
                .distinct
    Agent.where(id: combined).order(:family)
  end

  def agent_counts
    occurrence_determiners_union_recorders
      .joins(:agent)
      .group(:agent_id)
      .order(Arel.sql("count(*) desc"))
      .count
  end

  def agent_counts_unclaimed
    determiners = OccurrenceDeterminer
                    .joins("INNER JOIN taxon_occurrences ON occurrence_determiners.occurrence_id = taxon_occurrences.occurrence_id")
                    .joins("LEFT OUTER JOIN user_occurrences ON taxon_occurrences.occurrence_id = user_occurrences.occurrence_id AND user_occurrences.action IN ('identified', 'identified,recorded', 'recorded,identified')")
                    .where(taxon_occurrences: { taxon_id: id })
                    .where(user_occurrences: { occurrence_id: nil })
                    .distinct
    recorders = OccurrenceRecorder
                    .joins("INNER JOIN taxon_occurrences ON occurrence_recorders.occurrence_id = taxon_occurrences.occurrence_id")
                    .joins("LEFT OUTER JOIN user_occurrences ON taxon_occurrences.occurrence_id = user_occurrences.occurrence_id AND user_occurrences.action IN ('recorded', 'identified,recorded', 'recorded,identified')")
                    .where(taxon_occurrences: { taxon_id: id })
                    .where(user_occurrences: { occurrence_id: nil })
                    .distinct
    recorders.union_all(determiners)
             .select(:agent_id, "count(*) AS count_all")
             .group(:agent_id)
             .order(count_all: :desc)
  end

  def timeline_recorded(start_year: 1000, end_year: Time.now.year)
    subq = UserOccurrence.from("user_occurrences FORCE INDEX (user_occurrence_idx)")
                         .select(:user_id, :eventDate_processed, :visible)
                         .joins(:occurrence)
                         .joins("INNER JOIN taxon_occurrences ON taxon_occurrences.occurrence_id = user_occurrences.occurrence_id")
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
    subq = UserOccurrence.from("user_occurrences FORCE INDEX (user_occurrence_idx)")
                         .select(:user_id, :dateIdentified_processed, :visible)
                         .joins(:occurrence)
                         .joins("INNER JOIN taxon_occurrences ON taxon_occurrences.occurrence_id = user_occurrences.occurrence_id")
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
