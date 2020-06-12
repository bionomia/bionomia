class TaxonOccurrence < ActiveRecord::Base
   belongs_to :occurrence
   belongs_to :taxon
   has_one :user_occurrence, foreign_key: :user_id, primary_key: :user_id

   validates :taxon_id, presence: true
   validates :occurrence_id, presence: true
end
