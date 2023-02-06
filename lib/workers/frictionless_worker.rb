# encoding: utf-8

module Bionomia
  class FrictionlessWorker
    include SuckerPunch::Job

    def perform(data)
      ActiveRecord::Base.connection_pool.with_connection do
        dataset = Dataset.find_by_uuid(data[:uuid])
        f = FrictionlessGenerator.new(dataset: dataset, output_directory: data[:output_directory])
        f.create
      end
    end

  end
end
