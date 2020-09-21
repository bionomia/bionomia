# encoding: utf-8

module Bionomia
  class TaxonWorker
    include Sidekiq::Worker
    sidekiq_options queue: :taxon

    def perform(row)
      taxon = Taxon.create_or_find_by(family: row["family"].to_s.strip)
      data = row["gbifIDs_family"]
                .tr('[]', '')
                .split(',')
                .in_groups_of(1000, false) do |group|
                  import = group.map{|r| [ r.to_i, taxon.id] }
                  TaxonOccurrence.import [:occurrence_id, :taxon_id],  import, batch_size: 1000, validate: false, on_duplicate_key_ignore: true
                end
    end

  end
end
