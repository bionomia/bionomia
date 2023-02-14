class OrphanedUserOccurrence < ActiveRecord::Base
  belongs_to :user_occurrence, foreign_key: :occurrence_id, primary_key: :occurrence_id

  def self.rebuild
    delete_all
    pbar = ProgressBar.create(title: "Orphaned", total: (UserOccurrence.count/10_000).to_i, autofinish: false, format: '%t %b>> %i| %e')
    UserOccurrence.in_batches(of: 10_000) do |relation|
      pbar.increment
      relation.where.missing(:occurrence).each do |uo|
        self.create({
          occurrence_id: uo.occurrence_id,
          user_id: uo.user_id,
          created_by: uo.created_by
      })
      end
    end
    pbar.finish
  end
 
 end