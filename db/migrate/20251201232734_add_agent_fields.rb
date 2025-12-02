class AddAgentFields < ActiveRecord::Migration[8.1]
  def up
    unless column_exists? :agents, :appellation
      add_column :agents, :appellation, :string, after: :given, limit: 25
      add_column :agents, :title, :string, after: :given, limit: 25
      add_column :agents, :particle, :string, after: :given, limit: 25
      add_column :agents, :dropping_particle, :string, after: :given, limit: 25
      add_column :agents, :suffix, :string, after: :given, limit: 25
      add_column :agents, :nick, :string, after: :given, limit: 25
    end

    if index_exists?(:agents, name: "full_name")
      remove_index :agents, name: 'full_name'
    end
    add_index :agents, [:family, :given, :particle, :appellation, :title, :suffix, :nick, :dropping_particle, :unparsed], name: 'full_name', unique: true
  end

  def down
    if column_exists? :agents, :appellation
      remove_column :agents, :appellation, :string, limit: 25
      remove_column :agents, :title, :string, limit: 25
      remove_column :agents, :particle, :string, limit: 25
      remove_column :agents, :dropping_particle, :string, limit: 25
      remove_column :agents, :suffix, :string, limit: 25
      remove_column :agents, :nick, :string, limit: 25
    end

    if index_exists?(:agents, name: "full_name")
      remove_index :agents, name: 'full_name'
    end
    add_index :agents, [:family, :given, :unparsed], name: 'full_name', unique: true
  end
end
