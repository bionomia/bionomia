class BulkAttributionAddAgent < ActiveRecord::Migration[7.0]
  def up
    unless column_exists? :bulk_attribution_queries, :agent_name
      add_column :bulk_attribution_queries, :agent_name, :string, after: :query
      add_column :bulk_attribution_queries, :not_them, :boolean, after: :agent_name
    end
  end

  def down
    if column_exists? :bulk_attribution_queries, :agent_name
      remove_column :bulk_attribution_queries, :not_them, :boolean
    end
  end
end
