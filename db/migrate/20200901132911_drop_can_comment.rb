class DropCanComment < ActiveRecord::Migration[6.0]
  def up
    if column_exists? :users, :can_comment
      remove_column :users, :can_comment, :integer, null: false, default: 1
    end
  end

  def down
    if !column_exists?(:users, :can_comment)
      add_column :users, :can_comment, :integer, null: false, default: 1
    end
  end
end
