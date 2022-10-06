class AddArticleProcessedStatus < ActiveRecord::Migration[7.0]
  def up
    unless column_exists? :articles, :process_status
      add_column :articles, :process_status, :integer, default: 0, after: :processed
    end
  end

  def down
    if column_exists? :articles, :process_status
      remove_column :articles, :process_status, :integer, default: 0, after: :processed
    end
  end
end
