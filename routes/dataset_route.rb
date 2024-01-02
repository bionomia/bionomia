# encoding: utf-8

module Sinatra
  module Bionomia
    module Route
      module DatasetRoute

        def self.registered(app)

          app.get '/datasets' do
            datasets
            haml :'datasets/datasets', locals: { active_page: "datasets" }
          end

          app.get '/datasets/search' do
            search_dataset
            haml :'datasets/search', locals: { active_page: "datasets" }
          end

          app.namespace '/dataset' do

            get '/:id.json' do
              content_type "application/json", charset: 'utf-8'
              dataset_stats.to_json
            end

            get '/:id/badge.svg' do
              content_type "image/svg+xml", charset: 'utf-8'
              @doc = search_dataset_by_uuid(params[:id])
              if @doc.nil?
                status 404
                haml :dataset_badge_svg_404, layout: false
              else
                haml :dataset_badge_svg, layout: false
              end
            end

            get '/:id/datapackage.json' do
              content_type "application/json", charset: 'utf-8'
              cache_control :public, :must_revalidate, :no_cache, :no_store
              file = File.join(app.root, "public", "data", "#{params[:id]}", "datapackage.json")
              if File.file?(file)
                send_file(file)
              else
                halt 404
              end
            end

            get '/:id/:file.csv.zip' do
              content_type "application/zip", charset: 'utf-8'
              cache_control :public, :must_revalidate, :no_cache, :no_store
              file = File.join(app.root, "public", "data", "#{params[:id]}", "#{params[:file]}.csv.zip")
              if File.file?(file)
                send_file(file)
              else
                halt 404
              end
            end

            get '/:id' do
              dataset_from_param
              dataset_users

              @frictionless_data = nil
              file = File.join(app.root, "public", "data", "#{@dataset.uuid}", "datapackage.json")
              if File.file?(file)
                data_hash = JSON.parse(File.read(file), symbolize_names: true)
                @frictionless_data = data_hash[:resources].map{|d| d.slice(:name, :path, :bytes) }
              end

              locals = {
                active_page: "datasets",
                active_tab: "people"
              }
              haml :'datasets/users', locals: locals
            end

            get '/:id/scribes' do
              dataset_from_param
              if @dataset.is_large?
                halt 404
              end
              dataset_scribes
              locals = {
                active_page: "datasets",
                active_tab: "scribes"
              }
              haml :'datasets/scribes', locals: locals
            end

            get '/:id/agents' do
              dataset_from_param
              if @dataset.is_large?
                halt 404
              end
              dataset_agents
              locals = {
                active_page: "datasets",
                active_tab: "agents",
                active_subtab: "default"
              }
              haml :'datasets/agents', locals: locals
            end

            get '/:id/agents/counts' do
              dataset_from_param
              if @dataset.is_large?
                halt 404
              end
              dataset_agents_counts
              locals = {
                active_page: "datasets",
                active_tab: "agents",
                active_subtab: "counts"
              }
              haml :'datasets/agents_counts', locals: locals
            end

            get '/:id/agents/unclaimed' do
              dataset_from_param
              if @dataset.is_large?
                halt 404
              end
              dataset_agents_unclaimed_counts
              locals = {
                active_page: "datasets",
                active_tab: "agents",
                active_subtab: "unclaimed"
              }
              haml :'datasets/agents_unclaimed', locals: locals
            end

            get '/:id/visualizations' do
              dataset_from_param
              if @dataset.is_large?
                halt 404
              end
              @action = "collected"
              if ["identified","collected"].include?(params[:action])
                @action = params[:action]
              end

              locals = {
                active_page: "datasets",
                active_tab: "visualizations",
                active_subtab: @action
              }

              start_year = 1000
              end_year = Time.now.year

              if params[:start_year] && !params[:start_year].empty?
                start_year = params[:start_year].to_i
              end

              if params[:end_year] && !params[:end_year].empty?
                end_year = params[:end_year].to_i
              end

              if @action == "collected"
                users = @dataset.timeline_recorded(start_year: start_year, end_year: end_year)
              elsif @action == "identified"
                users = @dataset.timeline_identified(start_year: start_year, end_year: end_year)
              end
              @timeline = users.map do |u|
                card = haml :'partials/user/tooltip', layout: false, locals: { user: u }
                [ u.identifier,
                  u.viewname,
                  card,
                  u.min_date.to_time.iso8601,
                  u.max_date.to_time.iso8601,
                  (u.date_born ? u.date_born.to_time.iso8601 : ""),
                  (u.date_died ? u.date_died.to_time.iso8601 : "")
                ].compact
              end
              haml :'datasets/visualizations', locals: locals
            end

            get '/:id/refresh.json' do
              content_type "application/json", charset: 'utf-8'
              protected!
              dataset = ::Bionomia::GbifDataset.new
              dataset.process_dataset(params[:id])
              { message: "ok" }.to_json
            end

            get '/:id/progress.json' do
              content_type "application/json"
              expires 0, :no_cache, :must_revalidate

              dataset_from_param
              total = @dataset.occurrences_count
              claimed = @dataset.claimed_occurrences_count
              unclaimed = (total - claimed < 0) ? 0 : total - claimed
              { claimed: claimed, unclaimed: unclaimed }.to_json
            end

            get '.json' do
              content_type "application/json", charset: 'utf-8'
              search_dataset
              format_datasets.to_json
            end

          end

        end

      end
    end
  end
end
