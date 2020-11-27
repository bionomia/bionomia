class TaxonImages < ActiveRecord::Migration[6.0]
  def up
    create_table :taxon_images, if_not_exists: true do |t|
      t.string :family, null: false
      t.string :file_name, null: false
    end
    if column_exists?(:taxon_images, :family)
      add_index  :taxon_images, :family, unique: true unless index_exists?(:taxon_images, :family)
    end
  end

  def down
    drop_table(:messages, if_exists: true)
  end
end
