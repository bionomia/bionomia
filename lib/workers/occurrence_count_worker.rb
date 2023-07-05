# encoding: utf-8

module Bionomia
  class OccurrenceCountWorker
    include Sidekiq::Job
    sidekiq_options queue: :occurrence_count, retry: 3

    def perform(row)
      data = JSON.parse(row, symbolize_names: true)
      occurrence_count = OccurrenceCount.find(data[:id])
      if !occurrence_count.has_candidate?
        occurrence_count.delete
      end
    end

  end
end
