class AddRecordedbyid < ActiveRecord::Migration[6.0]
  def up
    unless column_exists? :occurrences, :recordedByID
      add_column :occurrences, :recordedByID, :text
    end
  end

  def down
    if column_exists? :occurrences, :recordedByID
      remove_column :occurrences, :recordedByID, :text
    end
  end
end
