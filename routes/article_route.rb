# encoding: utf-8

module Sinatra
  module Bionomia
    module Route
      module ArticleRoute

        def self.registered(app)

          app.get '/articles' do
            articles = Article.where(processed: true)
                              .where.not(citation: nil)
                              .order(created: :desc)
            @pagy, @results = pagy(articles, items: 25)
            haml :'articles/articles', locals: { active_page: "articles" }
          end

          app.namespace '/article' do

            get '/search' do
              if params.has_key?("q") && params[:q].blank?
                redirect "/articles"
              end
              search_article
              haml :'articles/search', locals: { active_page: "articles" }
            end

            get '/*/agents/counts' do
              locals = {
                active_page: "articles",
                active_tab: "agents",
                active_subtab: "counts"
              }
              if authorized?
                article_agents_counts
                @stats = cache_block("article-#{@article.id}-stats") { article_stats(@article) }
                haml :'articles/agents_counts', locals: locals
              else
                article_from_param
                @stats = cache_block("article-#{@article.id}-stats") { article_stats(@article) }
                haml :'articles/agents_unauthorized', locals: locals
              end
            end

            get '/*/agents/unclaimed' do
              locals = {
                active_page: "articles",
                active_tab: "agents",
                active_subtab: "unclaimed"
              }
              if authorized?
                article_agents_unclaimed
                @stats = cache_block("article-#{@article.id}-stats") { article_stats(@article) }
                haml :'articles/agents_unclaimed', locals: locals
              else
                article_from_param
                @stats = cache_block("article-#{@article.id}-stats") { article_stats(@article) }
                haml :'articles/agents_unauthorized', locals: locals
              end
            end

            get '/*/agents' do
              locals = {
                active_page: "articles",
                active_tab: "agents",
                active_subtab: "default"
              }
              if authorized?
                article_agents
                @stats = cache_block("article-#{@article.id}-stats") { article_stats(@article) }
                haml :'articles/agents', locals: locals
              else
                article_from_param
                @stats = cache_block("article-#{@article.id}-stats") { article_stats(@article) }
                haml :'articles/agents_unauthorized', locals: locals
              end
            end

            get '/*' do
              article_users
              locals = {
                active_page: "articles",
                active_tab: "people"
              }
              @stats = cache_block("article-#{@article.id}-stats") { article_stats(@article) }
              haml :'articles/users', locals: locals
            end

          end

        end

      end
    end
  end
end
