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

          client = Elasticsearch::Client.new(
            url: Settings.elastic.server,
            request_timeout: 5*60,
            retry_on_failure: true,
            reload_on_failure: true,
            reload_connections: 1_000,
            adapter: :typhoeus
          )
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
          @results = Taxon.joins(:image)
                          .where.not(image: {file_name: nil })
                          .limit(50)
                          .order(Arel.sql("RAND()"))
        end

        def taxon_image(taxon, size=nil)
          img = nil
          cloud_img = "https://abekpgaoen.cloudimg.io/v7/"
          path = "?force_format=jpg&width=64&org_if_sml=1"
          if size == "thumbnail"
            path = "?force_format=jpg&width=24&org_if_sml=1"
          end
          taxon_image = TaxonImage.find_by_family(taxon) rescue nil
          if taxon_image
            img = cloud_img + URI(Settings.base_url).host + "/images/taxa/" + taxon_image.file_name + path
          end
          img
        end

      end
    end
  end
end
