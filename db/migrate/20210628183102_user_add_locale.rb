class UserAddLocale < ActiveRecord::Migration[6.1]
  def up
    unless column_exists? :users, :locale
      add_column :users, :locale, :string, after: :youtube_id, limit: 2
    end
  end

  def down
    remove_column :users, :locale, :string
  end
end
