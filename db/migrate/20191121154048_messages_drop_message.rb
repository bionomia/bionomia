class MessagesDropMessage < ActiveRecord::Migration[6.0]
  def up
    remove_column :messages, :message if column_exists?(:messages, :message)
  end

  def down
    add_column :messages, :message, :text if !column_exists(:messages, :message)
  end
end
