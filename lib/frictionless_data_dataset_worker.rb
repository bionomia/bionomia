# encoding: utf-8

module Bionomia
  class FrictionlessDataDatasetWorker
    include SuckerPunch::Job

    def perform(data)
      ActiveRecord::Base.connection_pool.with_connection do
        fd = FrictionlessDataDataset.new(uuid: data[:uuid], output_directory: data[:output_directory])
        fd.create_package
        fd.update_frictionless_created
      end
    end

  end
end
