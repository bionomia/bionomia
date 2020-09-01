# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module DatasetHelper

        def dataset_from_param
          @dataset = Dataset.find_by_datasetKey(params[:id]) rescue nil
          if @dataset.nil?
            halt 404
          end
        end

        def search_dataset
          searched_term = params[:q] || params[:dataset]
          @results = []
          return if !searched_term.present?

          page = (params[:page] || 1).to_i

          client = Elasticsearch::Client.new url: Settings.elastic.server
          body = build_dataset_query(searched_term)
          from = (page -1) * 30

          response = client.search index: Settings.elastic.dataset_index, from: from, size: 30, body: body
          results = response["hits"].deep_symbolize_keys

          @pagy = Pagy.new(count: results[:total][:value], items: 30, page: page)
          @results = results[:hits]
        end

        def datasets
          if params[:order] && Dataset.column_names.include?(params[:order]) && ["asc", "desc"].include?(params[:sort])
            data = Dataset.order("#{params[:order]} #{params[:sort]}")
          else
            data = Dataset.order(:title)
          end
          begin
            @pagy, @results = pagy(data)
          rescue Pagy::OverflowError
            halt 404
          end
        end

        def dataset_users
          dataset_from_param
          begin
            @pagy, @results = pagy(@dataset.users.order(:family))
          rescue Pagy::OverflowError
            halt 404
          end
        end

        def dataset_agents
          dataset_from_param
          begin
            @pagy, @results = pagy_array(@dataset.agents.to_a, items: 75)
          rescue Pagy::OverflowError
            halt 404
          end
        end

        def dataset_agents_counts
          dataset_from_param
          begin
            @pagy, @results = pagy_array(@dataset.agents_occurrence_counts.to_a, items: 75)
          rescue Pagy::OverflowError
            halt 404
          end
        end

        def dataset_agents_unclaimed_counts
          dataset_from_param
          begin
            @pagy, @results = pagy_array(@dataset.agents_occurrence_unclaimed_counts.to_a, items: 75)
          rescue Pagy::OverflowError
            halt 404
          end
        end

        def dataset_stats
          dataset_from_param
          { people: @dataset.users.count }
        end

        def dataset_scribes
          dataset_from_param
          begin
            @pagy, @results = pagy(@dataset.scribes.order(:family))
          rescue Pagy::OverflowError
            halt 404
          end
        end

      end
    end
  end
end
