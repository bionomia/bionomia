# encoding: utf-8

module Bionomia
  class ArticleWorker
    include Sidekiq::Job
    sidekiq_options queue: :article, retry: 1

    def perform(row)
      gt = GbifTracker.new({ first_page_only: true })
      article = Article.find(row["id"]) rescue nil
      return if article.nil?
      gt.process_article(article)
    end

  end
end
