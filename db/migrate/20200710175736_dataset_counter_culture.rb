class DatasetCounterCulture < ActiveRecord::Migration[6.0]
  def up
    unless column_exists? :datasets, :occurrences_count
      add_column :datasets, :occurrences_count, :integer, null: false, default: 0
    end
  end

  def down
    if column_exists? :datasets, :occurrences_count
      remove_column :datasets, :occurrences_count, :integer, null: false, default: 0
    end
  end
end
