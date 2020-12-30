# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module ArticleController

        def self.registered(app)

          app.get '/articles' do
            articles = Article.where(processed: true).order(created: :desc)
            @pagy, @results = pagy(articles, items: 10)
            haml :'articles/articles', locals: { active_page: "articles" }
          end

          app.get '/article/search' do
            search_article
            haml :'articles/search', locals: { active_page: "articles" }
          end

          app.get '/article/*/agents/counts' do
            article_agents_counts
            locals = {
              active_page: "articles",
              active_tab: "agents",
              active_subtab: "counts"
            }
            haml :'articles/agents_counts', locals: locals
          end

          app.get '/article/*/agents/unclaimed' do
            article_agents_unclaimed
            locals = {
              active_page: "articles",
              active_tab: "agents",
              active_subtab: "unclaimed"
            }
            haml :'articles/agents_unclaimed', locals: locals
          end

          app.get '/article/*/agents' do
            article_agents
            locals = {
              active_page: "articles",
              active_tab: "agents",
              active_subtab: "default"
            }
            haml :'articles/agents', locals: locals
          end

          app.get '/article/*' do
            article_users
            locals = {
              active_page: "articles",
              active_tab: "people"
            }
            haml :'articles/users', locals: locals
          end

        end

      end
    end
  end
end
