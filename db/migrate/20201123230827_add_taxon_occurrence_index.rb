class AddTaxonOccurrenceIndex < ActiveRecord::Migration[6.0]
  def up
    if !index_exists?(:taxon_occurrences, :taxon_id)
      add_index :taxon_occurrences, :taxon_id
    end
  end

  def down
    if index_exists?(:taxon_occurrences, :taxon_id)
      remove_index :taxon_occurrences, :taxon_id
    end
  end
end
