class TaxonOccurrence < ActiveRecord::Base

   self.primary_key = :occurrence_id

   belongs_to :occurrence
   belongs_to :taxon

   has_one :user_occurrence, primary_key: :occurrence_id, foreign_key: :occurrence_id
   has_many :occurrence_agents, primary_key: :occurrence_id, foreign_key: :occurrence_id

   validates :taxon_id, presence: true
   validates :occurrence_id, presence: true
end
