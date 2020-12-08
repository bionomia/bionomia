class AddTaxonImagesCredit < ActiveRecord::Migration[6.0]
  def up
    unless column_exists? :taxon_images, :credit
      add_column :taxon_images, :credit, :string
      add_column :taxon_images, :licenseURL, :string
    end
  end

  def down
    if column_exists? :taxon_images, :credit
      remove_column :taxon_images, :credit, :string
      remove_column :taxon_images, :licenseURL, :string
    end
  end
end
