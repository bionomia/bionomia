class MessagesDropOccurrence < ActiveRecord::Migration[6.0]
  def up
    remove_column :messages, :occurrence_id if column_exists?(:messages, :occurrence_id)
  end

  def down
    add_column :messages, :occurrence_id, :bigint if !column_exists(:messages, :occurrence_id)
  end
end
