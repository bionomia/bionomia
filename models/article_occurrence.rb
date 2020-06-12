class ArticleOccurrence < ActiveRecord::Base

   self.primary_keys = :article_id, :occurrence_id

   belongs_to :occurrence
   belongs_to :article

   has_many :user_occurrences, primary_key: :occurrence_id, foreign_key: :occurrence_id

   validates :occurrence_id, presence: true
   validates :article_id, presence: true

   def self.orphaned_count
     self.left_joins(:occurrence).where(occurrences: { id: nil }).count
   end

   def self.orphaned_delete
     self.select(:id)
         .left_joins(:occurrence)
         .where(occurrences: { id: nil })
         .find_in_batches(batch_size: 10_000) do |ids|
       self.where(id: ids).delete_all
     end
   end

end
