class AddUsersLabel < ActiveRecord::Migration[7.0]
  def up
    unless column_exists? :users, :label
      add_column :users, :label, :string, before: :orcid
    end
  end

  def down
    if column_exists? :users, :label
      remove_column :users, :label, :string
    end
  end
end
