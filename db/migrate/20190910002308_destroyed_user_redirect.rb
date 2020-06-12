class DestroyedUserRedirect < ActiveRecord::Migration[6.0]
  def up
    unless column_exists? :destroyed_users, :redirect_to
      add_column :destroyed_users, :redirect_to, :string, limit: 25
    end
  end
  
  def down
    if column_exists? :destroyed_users, :redirect_to
      remove_column :destroyed_users, :redirect_to, :string, limit: 25
    end
  end
end
