# encoding: utf-8

module Bionomia
  class ArticleWorker
    include SuckerPunch::Job

    def perform(data)
      ActiveRecord::Base.connection_pool.with_connection do
        gt = GbifTracker.new({ first_page_only: true })
        gt.process_article(data[:article_id])
      end
    end

  end
end
