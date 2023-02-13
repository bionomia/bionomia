class CreateOrphanedUserOccurrences < ActiveRecord::Migration[7.0]
  def up
    create_table :orphaned_user_occurrences, if_not_exists: true do |t|
      t.bigint :occurrence_id, null: false
      t.integer :user_id, null: false
      t.integer :created_by, null: false
      t.timestamp :created_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamp :updated_at
    end
    if column_exists?(:messages, :user_id)
      add_index  :orphaned_user_occurrences, :occurrence_id unless index_exists?(:orphaned_user_occurrences, :occurrence_id)
    end
  end

  def down
    drop_table(:messages, if_exists: true)
  end
end
