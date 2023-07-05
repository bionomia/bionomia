# encoding: utf-8

module Bionomia
  class FrictionlessWorker
    include Sidekiq::Job
    sidekiq_options queue: :frictionless, retry: 3

    def perform(row)
      data = JSON.parse(row, symbolize_names: true)
      dataset = Dataset.find_by_uuid(data[:uuid]) rescue nil
      return if dataset.nil?
      f = FrictionlessGenerator.new(dataset: dataset, output_directory: data[:output_directory])
      f.create
    end

  end
end
