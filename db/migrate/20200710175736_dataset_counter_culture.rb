class DatasetCounterCulture < ActiveRecord::Migration[6.0]
  def up
    add_column :datasets, :occurrences_count, :integer, null: false, default: 0
  end

  def down
    remove_column :datasets, :occurrences_count, :integer, null: false, default: 0
  end
end
