# encoding: utf-8

module Bionomia
  class TaxonWorker
    include Sidekiq::Job
    sidekiq_options queue: :taxon, retry: 3

    def perform(row)
      data = JSON.parse(row, symbolize_names: true)
      taxon = Taxon.create_or_find_by(family: data[:family].to_s.strip)
      data = data[:gbifIDs_family]
                .tr('[]', '')
                .split(",")
                .in_groups_of(1000, false) do |group|
                  import = group.map{|r| [ r.to_i, taxon.id] }
                  TaxonOccurrence.import [:occurrence_id, :taxon_id],  import, batch_size: 1000, validate: false, on_duplicate_key_ignore: true
                end
    end

  end
end
