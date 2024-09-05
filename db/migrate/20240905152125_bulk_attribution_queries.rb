class BulkAttributionQueries < ActiveRecord::Migration[7.0]
  def up
    create_table :bulk_attribution_queries, if_not_exists: true do |t|
      t.integer :user_id, null: false
      t.integer :created_by, null: false
      t.text :query
      t.timestamps
    end
    if column_exists?(:bulk_attribution_queries, :user_id) && !index_exists?(:bulk_attribution_queries, :user, name: 'user_idx')
      add_index :bulk_attribution_queries, :user_id, name: 'user_idx'
    end
    if column_exists?(:bulk_attribution_queries, :created_by) && !index_exists?(:bulk_attribution_queries, :created_by, name: 'created_by_idx')
      add_index :bulk_attribution_queries, :created_by, name: 'created_by_idx'
    end
  end

  def down
    drop_table(:bulk_attribution_queries, if_exists: true)
  end
end