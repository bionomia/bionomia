class SourceAttributionCount < ActiveRecord::Migration[7.0]
  def up
    unless column_exists? :datasets, :source_attribution_count
      add_column :datasets, :source_attribution_count, :integer, null: false, default: 0
    end
  end

  def down
    if column_exists? :datasets, :source_attribution_count
      remove_column :datasets, :source_attribution_count
    end
  end
end
