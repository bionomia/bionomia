class BornDiedPrecision < ActiveRecord::Migration[6.0]
  def up
    unless column_exists? :users, :date_born_precision
      add_column :users, :date_born_precision, :string, after: :date_born
      User.where.not(wikidata: nil).update_all({ date_born_precision: "day" })
    end
    unless column_exists? :users, :date_died_precision
      add_column :users, :date_died_precision, :string, after: :date_died
      User.where.not(wikidata: nil).update_all({ date_died_precision: "day" })
    end
  end

  def down
    if column_exists? :users, :date_born_precision
      remove_column :users, :date_born_precision, :string
    end
    if column_exists? :users, :date_died_precision
      remove_column :users, :date_died_precision, :string
    end
  end
end
