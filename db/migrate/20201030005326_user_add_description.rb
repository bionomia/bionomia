class UserAddDescription < ActiveRecord::Migration[6.0]
  def up
    unless column_exists? :users, :description
      add_column :users, :description, :text, after: :keywords
    end
  end

  def down
    if column_exists? :users, :description
      remove_column :users, :description, :text, after: :keywords
    end
  end
end
