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
    occurrence_determiners_union_recorders
      .joins("LEFT JOIN user_occurrences ON occurrence_recorders.occurrence_id = user_occurrences.occurrence_id")
      .joins(:agent)
      .where(user_occurrences: { occurrence_id: nil })
      .group(:agent_id)
      .order(Arel.sql("count(*) desc"))
      .count
  end

end
