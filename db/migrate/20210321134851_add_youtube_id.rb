class AddYoutubeId < ActiveRecord::Migration[6.1]
  def up
    unless column_exists? :users, :youtube_id
      add_column :users, :youtube_id, :string, after: :signature_url
    end
  end

  def down
    remove_column :users, :youtube_id, :string
  end
end
