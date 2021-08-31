# encoding: utf-8

module Bionomia
  class OccurrenceCountWorker
    include Sidekiq::Worker
    sidekiq_options queue: :occurrence_count

    def perform(row)
      occurrence_count = OccurrenceCount.find(row["id"])
      occurrence_count.update_candidate
    end

  end
end
