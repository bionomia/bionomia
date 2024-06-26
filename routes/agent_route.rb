# encoding: utf-8

module Sinatra
  module Bionomia
    module Route
      module AgentRoute

        def self.registered(app)

          app.get '/agents' do
            body = {
              query: {
                bool: {
                  must_not: [
                    { term: { family: { value: "" } } }
                  ]
                }
              }
            }
            @count = ::Bionomia::ElasticAgent.new.count(body: body)
            if params[:q] && !params[:q].empty?
              search_agent({ item_size: 75 })
              @formatted_results = format_agents
            else
              @results = agent_examples
            end
            haml :'agents/agents', locals: { active_page: "agents" }
          end

          app.get '/agents/gbifID' do
            @gbifIDs = UserOccurrence.where(visible: true)
                                     .limit(20)
                                     .pluck(:occurrence_id)
            @output = []
            haml :'agents/gbifid', locals: { active_page: "agents" }
          end

          app.post '/agents/gbifID' do
            @gbifIDs = UserOccurrence.where(visible: true)
                                     .limit(20)
                                     .pluck(:occurrence_id)
            lines = params[:gbifids].split("\r\n")[0..50_000]
            agent_data = {}
            lines.each_slice(100) do |group|
              cols = OccurrenceAgent
                            .joins(:occurrence)
                            .where(occurrence_id: group)
                            .where(agent_role: true)
                            .pluck(:agent_id, :year, :family, :institutionCode)
              cols.each do |col|
                agent_data[col[0]] = [] if !agent_data.key?(col[0])
                agent_data[col[0]] << [col[1], col[2], col[3]]
              end
            end
            @output = agent_data.map{|k,v|
              {
                agent_id: k,
                count: v.count,
                event_range: v.map{|a| a[0]}.compact.uniq.minmax.join("–"),
                families: v.map{|a| a[1]}.compact.uniq.sort.join(" | "),
                institution_codes: v.map{|a| a[2]}.compact.uniq.sort.join(" | ") }
            }.sort_by{|a| -a[:count]}
            haml :'agents/gbifid', locals: { active_page: "agents" }
          end

          app.namespace '/agent' do

            get '/:id' do
              id = params[:id].to_i
              agent_filter

              sort = params[:sort] || nil
              order = params[:order] || nil
              locals = {
                active_page: "agents",
                sort: sort, order: order
              }

              begin
                @agent = Agent.find(id)
                raise if !@agent.unparsed.blank?
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
              rescue
                status 404
                haml :oops, locals: locals
              end
            end

            get '/:id/specimens.csv' do
              protected!
              content_type "text/csv", charset: 'utf-8'
              id = params[:id].to_i
              agent = Agent.find(id)
              records = agent.occurrences
              csv_stream_headers(agent.id)
              io = ::Bionomia::IO.new
              body io.csv_stream_agent_occurrences(records)
            end

            get '.json' do
              content_type "application/json", charset: 'utf-8'
              search_agent
              format_agents.to_json
            end

          end

        end

      end
    end
  end
end
