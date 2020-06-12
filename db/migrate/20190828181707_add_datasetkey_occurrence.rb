class AddDatasetkeyOccurrence < ActiveRecord::Migration[6.0]
  def up
    unless column_exists? :occurrences, :datasetKey
      add_column :occurrences, :datasetKey, :string, after: :gbifID, limit: 50
      add_index :occurrences, :datasetKey
    end
  end
  
  def down
    if column_exists? :occurrences, :datasetKey
      remove_column :occurrences, :datasetKey, :string, after: :gbifID, limit: 50
      remove_index :occurrences, :datasetKey
    end
  end
end
