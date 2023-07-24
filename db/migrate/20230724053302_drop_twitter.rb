class DropTwitter < ActiveRecord::Migration[7.0]
  def up
    if column_exists? :users, :twitter
      remove_column :users, :twitter, :string
    end
  end

  def down
    unless !column_exists? :users, :twitter
      add_column :users, :twitter, :twitter
    end
  end
end
