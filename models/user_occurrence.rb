class UserOccurrence < ActiveRecord::Base
   belongs_to :occurrence, foreign_key: :gbifID, primary_key: :occurrence_id
   belongs_to :user, foreign_key: :id, primary_key: :user_id
   belongs_to :claimant, foreign_key: :created_by, class_name: "User"

   has_one :user, foreign_key: :id, primary_key: :user_id
   has_one :occurrence, foreign_key: :gbifID, primary_key: :occurrence_id
   has_one :taxon_occurrence, foreign_key: :occurrence_id, primary_key: :occurrence_id

   has_many :shared_user_occurrences, -> (object){ where("id != ? AND visible = true", object.id) }, class_name: "UserOccurrence", foreign_key: :occurrence_id, primary_key: :occurrence_id
   has_many :article_occurrences, primary_key: :occurrence_id, foreign_key: :occurrence_id

   before_update :set_update_time

   alias_attribute :user_occurrence_id, :id

   validates :occurrence_id, presence: true
   validates :user_id, presence: true
   validates :created_by, presence: true

   def self.accepted_actions
     ["identified","recorded","identified,recorded","recorded,identified"]
   end

   def self.orphaned_count
     self.left_joins(:occurrence)
         .where(occurrences: { id: nil })
         .where(visible: true)
         .count
   end

   def self.orphaned_user_claims
     self.select(:user_id)
         .left_joins(:occurrence)
         .where(occurrences: { id: nil })
         .where(visible: true)
         .group(:user_id)
         .order("NULL")
         .count
         .sort_by { |_key, value| value }
         .reverse
         .map{ |_key, value|
           { user_id: _key, name: User.find(_key).fullname, orphaned: value }
         }
   end

   def self.delete_orphaned
     self.in_batches(of: 10_000) do |batch|
       ids = batch.left_joins(:occurrence)
                  .where(occurrences: { id: nil })
                  .pluck(:id)
       if ids.length > 0
         self.where(id: ids).delete_all
       end
     end
   end

   def recorded?
     action.include? "recorded"
   end

   def identified?
     action.include? "identified"
   end

   def shared?
     !shared_user_occurrences.empty?
   end

   private

   def set_update_time
     self.updated = Time.now
   end

end
