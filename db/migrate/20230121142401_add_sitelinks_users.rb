class AddSitelinksUsers < ActiveRecord::Migration[7.0]
  def up
    unless column_exists? :users, :wiki_sitelinks
      add_column :users, :wiki_sitelinks, :text, before: :created
    end
  end

  def down
    if column_exists? :users, :wiki_sitelinks
      remove_column :users, :wiki_sitelinks, :text
    end
  end
end
