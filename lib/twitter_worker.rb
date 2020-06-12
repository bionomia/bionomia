# encoding: utf-8

module Bionomia
  class TwitterWorker
    include SuckerPunch::Job

    def perform(data)
      twitter = Twitter.new
      user = User.find(data[:user_id])
      twitter.welcome_user(user)
    end

  end
end
