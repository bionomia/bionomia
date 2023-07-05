# encoding: utf-8

module Bionomia
  class ArticleWorker
    include Sidekiq::Job
    sidekiq_options queue: :article, retry: 3

    def perform(row)
      data = JSON.parse(row, symbolize_names: true)
      gt = GbifTracker.new({ first_page_only: true })
      article = Article.find(data[:article_id]) rescue nil
      return if article.nil?
      gt.process_article(article)
    end

  end
end
