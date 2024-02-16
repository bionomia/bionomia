class TaxonOccurrence < ActiveRecord::Base
   belongs_to :occurrence
   belongs_to :taxon

   has_one :user_occurrence, foreign_key: :occurrence_id, primary_key: :occurrence_id
   has_many :occurrence_agents, primary_key: :occurrence_id, foreign_key: :occurrence_id

   validates :taxon_id, presence: true
   validates :occurrence_id, presence: true
end
