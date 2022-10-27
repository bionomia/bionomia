# encoding: utf-8

module Bionomia
  class ArticleWorker
    include SuckerPunch::Job

    def perform(data)
      ActiveRecord::Base.connection_pool.with_connection do
        gt = GbifTracker.new({ first_page_only: true })
        article = Article.find(data[:article_id])
        gt.process_article(article)
      end
    end

  end
end
