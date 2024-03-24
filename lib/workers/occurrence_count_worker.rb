# encoding: utf-8

module Bionomia
  class OccurrenceCountWorker
    include Sidekiq::Job
    sidekiq_options queue: :default, retry: 0

    def perform(row)
      occurrence_count = OccurrenceCount.find(row["id"]) rescue nil
      if occurrence_count && !occurrence_count.has_candidate?
        occurrence_count.delete
      end
    end

  end
end
