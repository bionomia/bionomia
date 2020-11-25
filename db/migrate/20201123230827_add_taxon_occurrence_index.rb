class AddTaxonOccurrenceIndex < ActiveRecord::Migration[6.0]
  def up
    if !index_exists?(:taxon_occurrences, :occurrence_id)
      add_index :taxon_occurrences, :occurrence_id
    end
  end

  def down
    if index_exists?(:taxon_occurrences, :occurrence_id)
      remove_index :taxon_occurrences, :occurrence_id
    end
  end
end
