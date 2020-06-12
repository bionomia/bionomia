# encoding: utf-8

module Bionomia
  class FrictionlessDataWorker
    include SuckerPunch::Job

    def perform(data)
      fd = FrictionlessData.new(data)
      fd.create_package
    end

  end
end
