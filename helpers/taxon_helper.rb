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

          client = Elasticsearch::Client.new url: Settings.elastic.server, request_timeout: 5*60, retry_on_failure: true, reload_on_failure: true
          client.transport.reload_connections!
          body = build_taxon_query(searched_term)
          from = (page -1) * 30

          response = client.search index: Settings.elastic.taxon_index, from: from, size: 30, body: body
          results = response["hits"].deep_symbolize_keys

          @pagy = Pagy.new(count: results[:total][:value], items: 30, page: page)
          @results = results[:hits]
        end

        def taxon_agents
          taxon_from_param
          page = (params[:page] || 1).to_i
          @pagy, @results = pagy_array(@taxon.agents.to_a, items: 75, page: page)
        end

        def taxon_agents_counts
          taxon_from_param
          page = (params[:page] || 1).to_i
          begin
            @pagy, @results = pagy_array(@taxon.agent_counts.to_a, items: 75, page: page)
          rescue Pagy::OverflowError
            halt 404
          end
        end

        def taxon_agents_unclaimed
          taxon_from_param
          page = (params[:page] || 1).to_i
          begin
            @pagy, @results = pagy_array(@taxon.agent_counts_unclaimed.to_a, items: 75, page: page)
          rescue Pagy::OverflowError
            halt 404
          end
        end

        def taxon_examples
          @results = Taxon.limit(50).order(Arel.sql("RAND()"))
        end

        def taxon_image(taxon, size=nil)
          img = nil
          cloud_img = "https://abekpgaoen.cloudimg.io/height/64/x/"
          if size == "thumbnail"
            cloud_img = "https://abekpgaoen.cloudimg.io/width/24/x/"
          end
          taxon_image = TaxonImage.find_by_family(taxon) rescue nil
          if taxon_image
            img = cloud_img + Settings.base_url + "/images/taxa/" + taxon_image.file_name
          end
          img
        end

      end
    end
  end
end
