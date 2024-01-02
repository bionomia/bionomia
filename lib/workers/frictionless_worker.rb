# encoding: utf-8

module Bionomia
  class FrictionlessWorker
    include Sidekiq::Job
    sidekiq_options queue: :frictionless, retry: 0

    def perform(row)
      dataset = Dataset.find_by_uuid(row["uuid"]) rescue nil
      return if dataset.nil?
      f = FrictionlessGenerator.new(dataset: dataset)
      f.create
    end

  end
end
