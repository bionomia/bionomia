class AddDatasetContact < ActiveRecord::Migration[8.0]
  def up
    unless column_exists? :datasets, :administrative_contact
      add_column :datasets, :administrative_contact, :text, after: :dataset_type
    end
  end

  def down
    if column_exists? :datasets, :administrative_contact
      remove_column :datasets, :administrative_contact, :text
    end
  end
end
