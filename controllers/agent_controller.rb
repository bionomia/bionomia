# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module AgentController

        def self.registered(app)

          app.get '/agent/:id' do
            id = params[:id].to_i
            page = (params[:page] || 1).to_i
            agent_filter

            sort = params[:sort] || nil
            order = params[:order] || nil
            locals = {
              active_page: "agents",
              sort: sort, order: order
            }

            #begin
              @agent = Agent.find(id)
              occurrences = @agent.occurrences
              if params[:datasetKey] && !params[:datasetKey].empty?
                occurrences = occurrences.where({ datasetKey: params[:datasetKey] })
              end
              if params[:taxon] && !params[:taxon].empty?
                occurrences = occurrences.where({ family: params[:taxon] })
              end
              if params[:order] && Occurrence.column_names.include?(params[:order]) && ["asc", "desc"].include?(params[:sort])
                occurrences = occurrences.order("#{params[:order]} #{params[:sort]}")
              end
              @pagy, @results = pagy(occurrences, page: page)
              haml :'agents/agent', locals: locals
            #rescue
              #status 404
              #haml :oops, locals: locals
            #end
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
