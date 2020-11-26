# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module AgentController

        def self.registered(app)

          app.get '/agent/:id' do
            id = params[:id].to_i
            page = (params[:page] || 1).to_i

            dataset_name = nil
            if params[:datasetKey]
              begin
                dataset_name = Dataset.find_by_datasetKey(params[:datasetKey]).title
              rescue
                halt 404
              end
            end

            taxon_name = nil
            if params[:taxon]
              begin
                taxon_name = Taxon.find_by_family(params[:taxon]).family
              rescue
                halt 404
              end
            end

            @filter = {
              dataset: dataset_name,
              taxon: taxon_name
            }.compact

            begin
              @agent = Agent.find(id)
              occurrences = @agent.occurrences
              if params[:datasetKey]
                occurrences = occurrences.where({ datasetKey: params[:datasetKey] })
              end
              if params[:taxon]
                occurrences = occurrences.where({ family: params[:taxon] })
              end
              @pagy, @results = pagy(occurrences, page: page)

              haml :'agents/agent', locals: { active_page: "agents" }
            rescue
              status 404
              haml :oops, locals: { active_page: "agents" }
            end
          end

          app.get '/agent/:id/specimens.csv' do
            protected!
            content_type "text/csv", charset: 'utf-8'
            id = params[:id].to_i
            agent = Agent.find(id)
            records = agent.occurrences
            csv_stream_headers(agent.id)
            io = ::Bionomia::IO.new
            body io.csv_stream_agent_occurrences(records)
          end

          app.get '/agents' do
            @count = Agent.count
            if params[:q] && !params[:q].empty?
              search_agent({ item_size: 75 })
              @formatted_results = format_agents
            else
              @results = agent_examples
            end
            haml :'agents/agents', locals: { active_page: "agents" }
          end

          app.get '/agent.json' do
            content_type "application/json", charset: 'utf-8'
            search_agent
            format_agents.to_json
          end

        end

      end
    end
  end
end
