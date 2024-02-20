# encoding: utf-8

module Sinatra
  module Bionomia
    module Route
      module TaxonRoute

        def self.registered(app)

          app.get '/taxa' do
            @taxon_results = []
            @count = Taxon.count
            if params[:q] && params[:q].present?
              search_taxon
              @taxon_results = format_taxon
            else
              @taxon_results = taxon_examples
            end
            haml :'taxa/taxa', locals: { active_page: "taxa" }
          end

          app.namespace '/taxon' do

            get '.json' do
              content_type "application/json", charset: 'utf-8'
              search_taxon
              format_taxon.to_json
            end

            get '/:taxon' do
              @count = Taxon.count
              taxon_from_param
              @results = []
              @action = "collected"
              if ["identified","collected"].include?(params[:action])
                @action = params[:action]
              end
              locals = {
                active_page: "taxa",
                active_tab: "people",
                active_subtab: @action
              }
              begin
                search_user_taxa
                haml :'taxa/users', locals: locals
              rescue
                halt 404, haml(:oops)
              end
            end

            get '/:taxon/people.csv' do
              content_type "application/csv", charset: 'utf-8'
              taxon_from_param
              attachment "#{params[:taxon]}.csv"
              cache_control :no_cache
              headers.delete("Content-Length")
              client = Elasticsearch::Client.new(
                url: Settings.elastic.server,
                request_timeout: 5*60,
                retry_on_failure: true,
                reload_on_failure: true,
                reload_connections: 1_000,
                adapter: :typhoeus
              )
              body = build_user_taxon_query(@taxon.family)
              response = client.search index: Settings.elastic.user_index, body: body, scroll: '5m'
              scroll_id = response['_scroll_id']
              header = [
                "name",
                "URI",
                "bionomia_url",
                "action",
                "date_born",
                "date_born_precision",
                "date_died",
                "date_died_precision"
              ]
              Enumerator.new do |y|
                y << CSV::Row.new(header, header, true).to_s
                loop do
                  hits = response.deep_symbolize_keys.dig(:hits, :hits)
                  break if hits.empty?

                  hits.each do |o|
                    uri = o[:_source][:orcid] ?
                            "https://orcid.org/#{o[:_source][:orcid]}" :
                            "http://www.wikidata.org/entity/#{o[:_source][:wikidata]}"
                    identifier = o[:_source][:orcid] || o[:_source][:wikidata]
                    identified = o[:_source][:identified].map{|f| f[:family]}
                                                         .uniq
                                                         .include?(@taxon.family)
                    recorded = o[:_source][:recorded].map{|f| f[:family]}
                                                     .uniq
                                                     .include?(@taxon.family)
                    action = []
                    action << "identified" if identified
                    action << "recorded" if recorded
                    data = [ o[:_source][:fullname],
                             uri,
                             "#{Settings.base_url}/#{identifier}",
                             action.join(","),
                             o[:_source][:date_born],
                             o[:_source][:date_born_precision],
                             o[:_source][:date_died],
                             o[:_source][:date_died_precision]
                           ]
                    y << CSV::Row.new(header, data).to_s
                  end
                  response = client.scroll(scroll: '5m', body: { scroll_id: scroll_id })
                end
              end
            end

            get '/:taxon/agents' do
              locals = {
                active_page: "taxa",
                active_tab: "agents",
                active_subtab: "default"
              }
              taxon_from_param
              haml :'taxa/under_repair', locals: locals
=begin
              taxon_agents
              haml :'taxa/agents', locals: locals
=end
            end

            get '/:taxon/agents/counts' do
              locals = {
                active_page: "taxa",
                active_tab: "agents",
                active_subtab: "counts"
              }
              taxon_from_param
              haml :'taxa/under_repair', locals: locals
=begin
              taxon_agents_counts
              haml :'taxa/agents_counts', locals: locals
=end
            end

            get '/:taxon/agents/unclaimed' do
              locals = {
                active_page: "taxa",
                active_tab: "agents",
                active_subtab: "unclaimed"
              }
              taxon_from_param
              haml :'taxa/under_repair', locals: locals
=begin
              taxon_agents_unclaimed
              haml :'taxa/agents_unclaimed', locals: locals
=end
            end

            get '/:taxon/visualizations' do
              taxon_from_param
              @action = "collected"
              if ["identified","collected"].include?(params[:action])
                @action = params[:action]
              end
              search_user_taxa
              locals = {
                active_page: "taxa",
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
                users = @taxon.timeline_recorded(start_year: start_year, end_year: end_year)
              elsif @action == "identified"
                users = @taxon.timeline_identified(start_year: start_year, end_year: end_year)
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
                 ]
              end
              haml :'taxa/visualizations', locals: locals
            end

          end

        end

      end
    end
  end
end
