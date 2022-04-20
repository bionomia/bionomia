class OccurrenceAddLicense < ActiveRecord::Migration[7.0]
  def up
    unless column_exists? :occurrences, :license
      add_column :occurrences, :license, :string, after: :datasetKey, limit: 125
    end
  end

  def down
    if column_exists? :occurrences, :license
      remove_column :occurrences, :license, :string, after: :datasetKey, limit: 125
    end
  end
end
