class IncreaseParticleLength < ActiveRecord::Migration[6.0]
  def up
    change_column :users, :particle, :string, limit: 50
  end
  
  def down
    change_column :users, :particle, :string, limit: 10
  end
end
