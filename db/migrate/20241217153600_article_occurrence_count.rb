class ArticleOccurrenceCount < ActiveRecord::Migration[8.0]
  def up
    unless column_exists? :articles, :gbif_occurrence_count
      add_column :articles, :gbif_occurrence_count, :bigint, after: :gbif_downloadkeys, default: 0
    end
  end

  def down
    if column_exists? :articles, :gbif_occurrence_count
      remove_column :articles, :gbif_occurrence_count, :bigint
    end
  end
end
