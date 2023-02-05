# encoding: utf-8

module Bionomia
  class OccurrenceCountWorker
    include Sidekiq::Worker
    sidekiq_options queue: :occurrence_count

    def perform(row)
      occurrence_count = OccurrenceCount.find(row["id"])
      if !occurrence_count.has_candidate?
        occurrence_count.delete
      end
    end

  end
end
