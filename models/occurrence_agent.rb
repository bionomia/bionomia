class OccurrenceAgent < ActiveRecord::Base

   has_many :occurrences, primary_key: :occurrence_id, foreign_key: :id
   has_many :agents, primary_key: :agent_id, foreign_key: :id
   has_many :user_occurrences, primary_key: :occurrence_id, foreign_key: :occurrence_id

   has_one :taxon_occurrence, primary_key: :occurrence_id, foreign_key: :occurrence_id
   has_one :taxon, through: :taxon_occurrence, source: :taxon

   has_one :article_occurrence, primary_key: :occurrence_id, foreign_key: :occurrence_id
   has_one :article, through: :article_occurrence, source: :article

   validates :occurrence_id, presence: true
   validates :agent_id, presence: true
   validates :agent_role, presence: true
end