class KeyValue < ActiveRecord::Migration[7.0]
  def up
    create_table :key_values, if_not_exists: true do |t|
      t.string :k, null: false
      t.text :v, null: false
    end
    if column_exists?(:key_values, :k) && !index_exists?(:key_values, :k)
      add_index :key_values, :k, unique: true
    end
  end

  def down
    drop_table(:key_values, if_exists: true)
  end
end
