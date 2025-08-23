# encoding: utf-8

module Bionomia
  class TaxonWorker
    include Sidekiq::Job
    sidekiq_options queue: :default, retry: 3

    def perform(row)
      family = row["family"].to_s.strip
      return if family.match(/\A[a-zA-Z]*\z/).blank?
      taxon = Taxon.create_or_find_by(family: family)
      slice = 5_000
      cols = [:occurrence_id, :taxon_id]
      row["gbifIDs_family"]
        .tr('[]', '')
        .split(',')
        .each_slice(slice) do |group|
          TaxonOccurrence.import cols, 
                                 group.map(&:to_i).zip([taxon.id]*slice), 
                                 validate: false, 
                                 on_duplicate_key_ignore: true
      end
    end

  end
end
