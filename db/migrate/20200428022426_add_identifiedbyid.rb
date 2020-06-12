class AddIdentifiedbyid < ActiveRecord::Migration[6.0]
  def up
    unless column_exists? :occurrences, :identifiedByID
      add_column :occurrences, :identifiedByID, :text
    end
  end

  def down
    if column_exists? :occurrences, :identifiedByID
      remove_column :occurrences, :identifiedByID, :text
    end
  end
end
