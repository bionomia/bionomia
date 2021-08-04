class ArticleOccurrence < ActiveRecord::Base

   belongs_to :occurrence
   belongs_to :article

   has_many :user_occurrences, primary_key: :occurrence_id, foreign_key: :occurrence_id

   validates :occurrence_id, presence: true
   validates :article_id, presence: true

   def self.orphaned_count
     counter = 0
     Article.find_each do |article|
       article_ids = article.article_occurrences.pluck(:occurrence_id)
       Parallel.each(article_ids.in_groups_of(10_000, false), in_threads: 4) do |group|
          occurrence_ids = Occurrence.where(id: group).pluck(:gbifID)
          counter = counter + (group - occurrence_ids).count
          puts counter.to_s.green
       end
     end
     counter
   end

   def self.orphaned_delete
     Article.find_each do |article|
       article_ids = article.article_occurrences.pluck(:occurrence_id)
       Parallel.each(article_ids.in_groups_of(10_000, false), in_threads: 4) do |group|
          occurrence_ids = Occurrence.where(id: group).pluck(:gbifID)
          missing = group - occurrence_ids
          self.where(occurrence_id: missing).delete_all
       end
     end
   end

end
