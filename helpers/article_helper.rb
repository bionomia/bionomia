# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module ArticleHelper

        def article_from_param
          if !params[:splat][0].is_doi?
            halt 404
          end
          @article = Article.find_by_doi(params[:splat][0]) rescue nil
          if @article.nil?
            halt 404
          end
        end

        def search_article
          searched_term = params[:q]
          @results = []
          return if !searched_term.present?

          page = (params[:page] || 1).to_i

          client = Elasticsearch::Client.new url: Settings.elastic.server, request_timeout: 5*60, retry_on_failure: true, reload_on_failure: true
          client.transport.reload_connections!
          body = build_article_query(searched_term)
          from = (page -1) * 30

          response = client.search index: Settings.elastic.article_index, from: from, size: 30, body: body
          results = response["hits"].deep_symbolize_keys

          @pagy = Pagy.new(count: results[:total][:value], items: 30, page: page)
          @results = results[:hits]
        end

        def article_users
          article_from_param
          @pagy, @results = pagy(@article.claimants.order(:family))
        end

        def article_agents
          article_from_param
          @pagy, @results = pagy_array(@article.agents.to_a, items: 75)
        end

        def article_agents_counts
          article_from_param
          @pagy, @results = pagy_array(@article.agents_occurrence_counts.to_a, items: 75)
        end

        def article_agents_unclaimed
          article_from_param
          @pagy, @results = pagy_array(@article.agents_occurrence_counts_unclaimed.to_a, items: 75)
        end

      end
    end
  end
end
