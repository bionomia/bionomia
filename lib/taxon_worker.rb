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
                .map{|r| [ r.to_i, taxon.id ] }
      if !data.empty?
        TaxonOccurrence.import [:occurrence_id, :taxon_id],  data, batch_size: 2500, validate: false, on_duplicate_key_ignore: true
      end
    end

  end
end
