class AddFrictionlessCreatedAt < ActiveRecord::Migration[6.1]
  def up
    unless column_exists? :datasets, :frictionless_created_at
      add_column :datasets, :frictionless_created_at, :timestamp, after: :updated_at
    end
  end

  def down
    if column_exists? :datasets, :frictionless_created_at
      remove_column :datasets, :frictionless_created_at, :timestamp, after: :updated_at
    end
  end
end
