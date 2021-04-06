class UserPublicIndex < ActiveRecord::Migration[6.1]
  def up
    if !index_exists?(:users, :is_public)
      add_index :users, :is_public
    end
  end

  def down
    if index_exists?(:users, :is_public)
      remove_index :users, :is_public
    end
  end
end
