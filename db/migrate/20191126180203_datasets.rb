class Datasets < ActiveRecord::Migration[6.0]
  def up
    create_table :datasets, if_not_exists: true do |t|
      t.text :datasetKey, limit: 50, null: false
      t.text :title
      t.text :description
      t.text :doi, limit: 255
      t.text :license, limit: 50
      t.text :image_url, limit: 255
      t.timestamp :created_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamp :updated_at
    end
    if column_exists?(:datasets, :datasetKey)
      add_index  :datasets, :datasetKey, length: 50, unique: true unless index_exists?(:datasets, :datasetKey)
    end
  end

  def down
    drop_table(:datasets, if_exists: true)
  end
end
