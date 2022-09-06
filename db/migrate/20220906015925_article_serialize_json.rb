class ArticleSerializeJson < ActiveRecord::Migration[7.0]
  def up
    unless column_exists? :articles, :gbif_dois_json
      add_column :articles, :gbif_dois_json, :text, after: :gbif_dois
    end
    unless column_exists? :articles, :gbif_downloadkeys_json
      add_column :articles, :gbif_downloadkeys_json, :text, after: :gbif_downloadkeys
    end

    Article.find_each do |a|
      a.gbif_dois_json = a.gbif_dois
      a.gbif_downloadkeys_json = a.gbif_downloadkeys
      a.save
    end

    remove_column :articles, :gbif_dois
    rename_column :articles, :gbif_dois_json, :gbif_dois

    remove_column :articles, :gbif_downloadkeys
    rename_column :articles, :gbif_downloadkeys_json, :gbif_downloadkeys
  end

  def down
  end
end
