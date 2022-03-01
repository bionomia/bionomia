class AddDatasetType < ActiveRecord::Migration[7.0]
  def up
    unless column_exists? :datasets, :dataset_type
      add_column :datasets, :dataset_type, :string, after: :image_url, limit: 25
    end
  end

  def down
    if column_exists? :datasets, :dataset_type
      remove_column :datasets, :dataset_type, :string, after: :image_url, limit: 25
    end
  end
end
