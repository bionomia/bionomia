# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module TaxonHelper

        def taxon_from_param
          @taxon = Taxon.where({ family: params[:taxon] }).first rescue nil
          if @taxon.nil?
            halt 404
          end
        end

        def search_taxon
          @results = []
          searched_term = params[:q] || params[:taxon]
          return if !searched_term.present?

          page = (params[:page] || 1).to_i
          from = (page -1) * 30
          body = build_taxon_query(searched_term)

          response = ::Bionomia::ElasticTaxon.new.search(from: from, size: 30, body: body)
          results = response["hits"].deep_symbolize_keys

          @pagy = Pagy.new(count: results[:total][:value], limit: 30, page: page)
          @results = results[:hits]
        end

        def taxon_agents
          taxon_from_param
          page = (params[:page] || 1).to_i
          @pagy, @results = pagy_array(@taxon.agents.to_a, limit: 75, page: page)
        end

        def taxon_agents_counts
          taxon_from_param
          page = (params[:page] || 1).to_i
          @pagy, @results = pagy_array(@taxon.agent_counts.to_a, limit: 75, page: page)
        end

        def taxon_agents_unclaimed
          taxon_from_param
          page = (params[:page] || 1).to_i
          @pagy, @results = pagy_array(@taxon.agent_counts_unclaimed.to_a, limit: 75, page: page)
        end

        def taxon_examples
          @results = Taxon.joins(:image)
                          .where.not(image: {file_name: nil })
                          .limit(50)
                          .order(Arel.sql("RAND()"))
        end

      end
    end
  end
end
