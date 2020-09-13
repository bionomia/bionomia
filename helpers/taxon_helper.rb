# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module TaxonHelper

        def search_taxon
          @results = []
          searched_term = params[:q]
          return if !searched_term.present?

          page = (params[:page] || 1).to_i

          client = Elasticsearch::Client.new url: Settings.elastic.server
          body = build_taxon_query(searched_term)
          from = (page -1) * 30

          response = client.search index: Settings.elastic.taxon_index, from: from, size: 30, body: body
          results = response["hits"].deep_symbolize_keys

          @pagy = Pagy.new(count: results[:total][:value], items: 30, page: page)
          @results = results[:hits]
        end

      end
    end
  end
end
