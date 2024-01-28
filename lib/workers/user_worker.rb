# encoding: utf-8

module Bionomia
  class UserWorker
    include Sidekiq::Job
    sidekiq_options queue: :critical, retry: 2
 
    def perform(row)
      user = User.find(row["id"])
      user.flush_caches
    end
 
  end
end
 