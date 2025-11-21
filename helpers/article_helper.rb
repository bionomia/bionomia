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
          from = (page -1) * 25
          body = build_article_query(searched_term)

          response = ::Bionomia::ElasticArticle.new.search(from: from, size: 30, body: body)
          results = response["hits"].deep_symbolize_keys

          @pagy = Pagy.new(count: results[:total][:value], limit: 25, page: page)
          @results = results[:hits]
        end

        def article_users
          article_from_param
          @pagy, @results = pagy(@article.claimants.order(:family))
        end

        def article_agents
          article_from_param
          @pagy, @results = pagy(@article.agents_with_family.order(:family), limit: 75)
        end

        def article_agents_counts
          article_from_param
          data = @article.agents_occurrence_counts.to_a.sort_by{|a| -a[:count_all]}
          @pagy, @results = pagy(:offset, data, count: data.size, limit: 75)
        end

        def article_agents_unclaimed
          article_from_param
          data = @article.agents_occurrence_counts_unclaimed.to_a.sort_by{|a| -a[:count_all]}
          @pagy, @results = pagy(:offset, data, count: data.size, limit: 75)
        end

        def article_stats(article)
          {
            claimed_count: article.claimed_specimen_count,
            occurrence_count: article.article_occurrences.count
          }
        end

      end
    end
  end
end
