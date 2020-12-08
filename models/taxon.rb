class Taxon < ActiveRecord::Base
  has_many :taxon_occurrences, dependent: :delete_all
  has_many :occurrences, through: :taxon_occurrences, source: :occurrence
  has_one :image, class_name: "TaxonImage", foreign_key: :family, primary_key: :family

  validates :family, presence: true

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

  def agents
    determiners = OccurrenceDeterminer
                    .joins("INNER JOIN taxon_occurrences ON occurrence_determiners.occurrence_id = taxon_occurrences.occurrence_id")
                    .where(taxon_occurrences: { taxon_id: id })
    recorders = OccurrenceRecorder
                    .joins("INNER JOIN taxon_occurrences ON occurrence_recorders.occurrence_id = taxon_occurrences.occurrence_id")
                    .where(taxon_occurrences: { taxon_id: id })
    recorders.union_all(determiners)
             .joins(:agent)
             .group(:agent_id)
             .order(Arel.sql("agents.family"))
             .count
  end

  def agent_counts
    determiners = OccurrenceDeterminer
                    .joins("INNER JOIN taxon_occurrences ON occurrence_determiners.occurrence_id = taxon_occurrences.occurrence_id")
                    .where(taxon_occurrences: { taxon_id: id })
    recorders = OccurrenceRecorder
                    .joins("INNER JOIN taxon_occurrences ON occurrence_recorders.occurrence_id = taxon_occurrences.occurrence_id")
                    .where(taxon_occurrences: { taxon_id: id })
    recorders.union(determiners)
             .joins(:agent)
             .group(:agent_id)
             .order(Arel.sql("count(*) desc"))
             .count
  end

  def agent_counts_unclaimed
    determiners = OccurrenceDeterminer
                    .joins("INNER JOIN taxon_occurrences ON occurrence_determiners.occurrence_id = taxon_occurrences.occurrence_id")
                    .joins("LEFT JOIN user_occurrences ON occurrence_determiners.occurrence_id = user_occurrences.occurrence_id")
                    .where(taxon_occurrences: { taxon_id: id })
                    .where(user_occurrences: { occurrence_id: nil })
                    .distinct
    recorders = OccurrenceRecorder
                    .joins("INNER JOIN taxon_occurrences ON occurrence_recorders.occurrence_id = taxon_occurrences.occurrence_id")
                    .joins("LEFT JOIN user_occurrences ON occurrence_recorders.occurrence_id = user_occurrences.occurrence_id")
                    .where(taxon_occurrences: { taxon_id: id })
                    .where(user_occurrences: { occurrence_id: nil })
                    .distinct
    recorders.union(determiners)
             .group(:agent_id)
             .order(Arel.sql("count(*) desc"))
             .count
  end

end
