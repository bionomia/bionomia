class UserSerializeJson < ActiveRecord::Migration[7.0]
  def up
    unless column_exists? :users, :zenodo_access_token_json
      add_column :users, :zenodo_access_token_json, :text, after: :zenodo_access_token
    end
    User.where.not(zenodo_access_token: nil).find_each do |u|
      u.zenodo_access_token_json = u.zenodo_access_token
      u.save
    end
    remove_column :users, :zenodo_access_token
    rename_column :users, :zenodo_access_token_json, :zenodo_access_token
  end

  def down
    if column_exists? :users, :zenodo_access_token_json
      remove_column :users, :zenodo_access_token_json, :text, after: :zenodo_access_token
    end
  end
end
