class DatasetZenodoDois < ActiveRecord::Migration[7.0]
  def up
    unless column_exists? :datasets, :zenodo_doi
      add_column :datasets, :zenodo_doi, :string
      add_column :datasets, :zenodo_concept_doi, :string
    end
  end

  def down
    if column_exists? :datasets, :zenodo_doi
      remove_column :datasets, :zenodo_doi, :string
      remove_column :datasets, :zenodo_concept_doi, :string
    end
  end
end
