class AddReasonDestroyedUsers < ActiveRecord::Migration[7.0]
  def up
    unless column_exists? :destroyed_users, :reason
      add_column :destroyed_users, :reason, :string
      add_column :destroyed_users, :created_at, :timestamp, default: -> { 'CURRENT_TIMESTAMP' }
    end
  end

  def down
    if column_exists? :destroyed_users, :reason
      remove_column :destroyed_users, :reason, :string
      remove_column :destroyed_users, :created_at, :timestamp
    end
  end
end
