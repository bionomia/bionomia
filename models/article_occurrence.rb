class ArticleOccurrence < ActiveRecord::Base

   belongs_to :occurrence
   belongs_to :article

   has_many :user_occurrences, primary_key: :occurrence_id, foreign_key: :occurrence_id

   validates :article_id, presence: true, uniqueness: { scope: :occurrence_id }
   validates :occurrence_id, presence: true

end
