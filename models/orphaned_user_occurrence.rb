class OrphanedUserOccurrence < ActiveRecord::Base
  belongs_to :user_occurrence, foreign_key: :occurrence_id, primary_key: :occurrence_id

  def self.rebuild
    delete_all

    Parallel.each(UserOccurrence.in_batches(of: 10_000), progress: "Building orphaned", in_threads: 4) do |relation|
      relation.where.missing(:occurrence).each do |uo|
        self.create({
          occurrence_id: uo.occurrence_id,
          user_id: uo.user_id,
          created_by: uo.created_by
        })
      end
    end
  end
 
 end