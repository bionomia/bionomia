class Messages < ActiveRecord::Migration[6.0]
  def up
    create_table :messages, if_not_exists: true do |t|
      t.integer :user_id, null: false
      t.integer :recipient_id, null: false
      t.bigint :occurrence_id
      t.text :message
      t.boolean :read, default: false
      t.timestamp :created_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamp :updated_at
    end
    if column_exists?(:messages, :user_id)
      add_index  :messages, :user_id unless index_exists?(:messages, :user_id)
    end
    if column_exists?(:messages, :recipient_id)
      add_index  :messages, :recipient_id unless index_exists?(:messages, :recipient_id)
    end
    if column_exists?(:messages, :occurrence_id)
      add_index  :messages, :occurrence_id unless index_exists?(:messages, :occurrence_id)
    end
  end

  def down
    drop_table(:messages, if_exists: true)
  end
end
