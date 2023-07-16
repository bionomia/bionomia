class OccurrenceRecorder < ActiveRecord::Base

   self.primary_key = :agent_id, :occurrence_id

   belongs_to :occurrence
   belongs_to :agent

   has_one :user_occurrence, primary_key: :occurrence_id, foreign_key: :occurrence_id
   
   has_one :taxon_occurrence, primary_key: :occurrence_id, foreign_key: :occurrence_id
   has_one :taxon, through: :taxon_occurrence, source: :taxon

   has_one :article_occurrence, primary_key: :occurrence_id, foreign_key: :occurrence_id
   has_one :article, through: :article_occurrence, source: :article

   validates :occurrence_id, presence: true
   validates :agent_id, presence: true
end
