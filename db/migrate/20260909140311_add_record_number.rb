class AddRecordNumber < ActiveRecord::Migration[8.1]
  def up
    unless column_exists? :occurrences, :recordNumber
      add_column :occurrences, :recordNumber, :text, after: :catalogNumber
    end
  end

  def down
    if column_exists? :occurrences, :recordNumber
      remove_column :occurrences, :recordNumber, :text
    end
  end
end
