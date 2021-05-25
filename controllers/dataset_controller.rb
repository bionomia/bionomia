# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module DatasetController

        def self.registered(app)

          app.get '/datasets' do
            datasets
            haml :'datasets/datasets', locals: { active_page: "datasets" }
          end

          app.get '/datasets/search' do
            search_dataset
            haml :'datasets/search', locals: { active_page: "datasets" }
          end

          app.get '/dataset/:id.json' do
            if params[:occurrenceID] && !params[:occurrenceID].empty?
              content_type "application/ld+json", charset: 'utf-8'
              response = jsonld_occurrence_context
              begin
                occurrence = Occurrence.where({ datasetKey: params[:id], occurrenceID: params[:occurrenceID] })
                                       .first
                response["@id"] = "#{Settings.base_url}/occurrence/#{occurrence.id}"
                response["sameAs"] = "https://gbif.org/occurrence/#{occurrence.id}"
                occurrence.attributes
                          .reject{|column| Occurrence::IGNORED_COLUMNS_OUTPUT.include?(column)}
                          .map{|k,v| response[k] = v }

                response["recorded"] = jsonld_occurrence_recordings(occurrence)
                response["identified"] = jsonld_occurrence_identifications(occurrence)
                response["associatedReferences"] = jsonld_occurrence_references(occurrence)
                JSON.pretty_generate(response)
              rescue
                halt 404, {}.to_json
              end
            else
              content_type "application/json", charset: 'utf-8'
              dataset_stats.to_json
            end
          end

          app.get '/dataset/:id/datapackage.json' do
            content_type "application/json", charset: 'utf-8'
            cache_control :public, :must_revalidate, :no_cache, :no_store
            file = File.join(app.root, "public", "data", "#{params[:id]}", "datapackage.json")
            if File.file?(file)
              send_file(file)
            else
              halt 404
            end
          end

          app.get '/dataset/:id/:file.csv.zip' do
            content_type "application/zip", charset: 'utf-8'
            cache_control :public, :must_revalidate, :no_cache, :no_store
            file = File.join(app.root, "public", "data", "#{params[:id]}", "#{params[:file]}.csv.zip")
            if File.file?(file)
              send_file(file)
            else
              halt 404
            end
          end

          app.get '/dataset/:id' do
            size = 0
            dir = File.join(app.root, "public", "data", "#{params[:id]}")
            if Dir.exists?(dir)
              Dir.foreach(dir) do |f|
                fn = File.join(dir, f)
                next if File.extname(fn) != ".zip"
                size = size + File.size(fn).to_f / 2**20
              end
            end
            @compressed_file_size = size.round(2) if size > 0
            dataset_users
            locals = {
              active_page: "datasets",
              active_tab: "people"
            }
            haml :'datasets/users', locals: locals
          end

          app.get '/dataset/:id/scribes' do
            dataset_scribes
            locals = {
              active_page: "datasets",
              active_tab: "scribes"
            }
            haml :'datasets/scribes', locals: locals
          end

          app.get '/dataset/:id/agents' do
            dataset_agents
            locals = {
              active_page: "datasets",
              active_tab: "agents",
              active_subtab: "default"
            }
            haml :'datasets/agents', locals: locals
          end

          app.get '/dataset/:id/agents/counts' do
            dataset_agents_counts
            locals = {
              active_page: "datasets",
              active_tab: "agents",
              active_subtab: "counts"
            }
            haml :'datasets/agents_counts', locals: locals
          end

          app.get '/dataset/:id/agents/unclaimed' do
            dataset_agents_unclaimed_counts
            locals = {
              active_page: "datasets",
              active_tab: "agents",
              active_subtab: "unclaimed"
            }
            haml :'datasets/agents_unclaimed', locals: locals
          end

          app.get '/dataset/:id/progress.json' do
            content_type "application/json"
            expires 0, :no_cache, :must_revalidate

            dataset_from_param
            total = @dataset.occurrences_count
            claimed = @dataset.claimed_occurrences_count
            { claimed: claimed, unclaimed: total - claimed }.to_json
          end

          app.get '/dataset.json' do
            content_type "application/json", charset: 'utf-8'
            search_dataset
            format_datasets.to_json
          end

        end

      end
    end
  end
end
