class OrganizationAddRor < ActiveRecord::Migration[6.1]
  def up
    unless column_exists? :organizations, :ror
      add_column :organizations, :ror, :string, after: :grid, limit: 9
      add_index :organizations, :ror
    end
  end

  def down
    remove_column :organizations, :ror, :string
    remove_index :organizations, :ror
  end
end
