class UserParticle < ActiveRecord::Migration[6.0]
  def up
    unless column_exists? :users, :particle
      add_column :users, :particle, :string, limit: 10, after: :given
    end
  end
  
  def down
    if column_exists? :users, :particle
      remove_column :users, :particle, :string, limit: 10
    end
  end
end
