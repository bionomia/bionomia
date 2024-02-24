# encoding: utf-8

module Bionomia
  class TaxonWorker
    include Sidekiq::Job
    sidekiq_options queue: :default, retry: 3

    def perform(row)
      family = row["family"].to_s.strip
      return if family.match(/\A[a-zA-Z]*\z/).blank?
      taxon = Taxon.create_or_find_by(family: family)
      row["gbifIDs_family"]
        .tr('[]', '')
        .split(',')
        .each_slice(2_500) do |group|
          import = group.map{|r| [ r.to_i, taxon.id] }
          TaxonOccurrence.import [:occurrence_id, :taxon_id],  import, validate: false, on_duplicate_key_ignore: true
      end
    end

  end
end
