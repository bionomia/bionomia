class SourceAttributions < ActiveRecord::Migration[7.0]
  def up
    create_table :source_users, if_not_exists: true do |t|
      t.string :identifier, null: false
    end
    if column_exists?(:source_users, :identifier) && !index_exists?(:source_users, :identifier)
      add_index :source_users, :identifier, unique: true
    end
    create_table :source_attributions, if_not_exists: true do |t|
      t.integer :user_id, null: false
      t.bigint :occurrence_id, null: false
      t.string :action, null: false
    end
    if column_exists?(:source_attributions, :user_id) && !index_exists?(:source_attributions, [:user_id, :occurrence_id, :action], name: 'source_attributions_composite')
      add_index :source_attributions, [:user_id, :occurrence_id, :action], name: 'source_attributions_composite', unique: true
    end
  end

  def down
    drop_table(:source_users, if_exists: true)
    drop_table(:source_attributions, if_exists: true)
  end
end
