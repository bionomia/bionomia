# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module ApplicationController

        def self.registered(app)

          app.get '/' do
            example_profiles
            haml :home, locals: { active_page: "home" }
          end

          app.get '/about' do
            haml :about, locals: { active_page: "about" }
          end

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

            @filter = {
              dataset: dataset_name
            }.compact

            begin
              @agent = Agent.find(id)
              occurrences = @agent.occurrences
              if params[:datasetKey]
                occurrences = occurrences.where({ datasetKey: params[:datasetKey] })
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
            search_agent({ item_size: 75 })
            @formatted_results = format_agents
            @count = Agent.count
            haml :'agents/agents', locals: { active_page: "agents" }
          end

          app.get '/articles' do
            articles = Article.where(processed: true).order(created: :desc)
            @pagy, @results = pagy(articles, items: 10)
            haml :'articles/articles', locals: { active_page: "articles" }
          end

          app.get '/article/search' do
            search_article
            haml :'articles/search', locals: { active_page: "articles" }
          end

          app.get '/article/*/agents/counts' do
            article_agents_counts
            locals = {
              active_page: "articles",
              active_tab: "agents",
              active_subtab: "counts"
            }
            haml :'articles/agents_counts', locals: locals
          end

          app.get '/article/*/agents' do
            article_agents
            locals = {
              active_page: "articles",
              active_tab: "agents",
              active_subtab: "default"
            }
            haml :'articles/agents', locals: locals
          end

          app.get '/article/*' do
            article_users
            locals = {
              active_page: "articles",
              active_tab: "people"
            }
            haml :'articles/users', locals: locals
          end

          app.get '/countries' do
            @results = []
            @countries = IsoCountryCodes
                          .for_select
                          .group_by{|u| ActiveSupport::Inflector.transliterate(u[0][0]) }
            haml :'countries/countries', locals: { active_page: "countries" }
          end

          app.get '/country/:country_code' do
            country_code = params[:country_code]
            @results = []
            begin
              @country = IsoCountryCodes.find(country_code)
              @action = params[:action] if ["identified","collected"].include?(params[:action])
              @family = params[:q].present? ? params[:q] : nil

              if @action || @family
                search_user_country
              else
                users = User.where("country_code LIKE ?", "%#{country_code}%")
                            .order(:family)
                @pagy, @results = pagy(users, items: 30)
              end
              haml :'countries/country', locals: { active_page: "countries" }
            rescue
              status 404
              haml :oops
            end
          end

          app.get '/datasets' do
            datasets
            haml :'datasets/datasets', locals: { active_page: "datasets" }
          end

          app.get '/datasets/search' do
            search_dataset
            haml :'datasets/search', locals: { active_page: "datasets" }
          end

          app.get '/dataset/:id.json' do
            content_type "application/json", charset: 'utf-8'
            dataset_stats.to_json
          end

          app.get '/dataset/:id.zip' do
            content_type "application/zip", charset: 'utf-8'
            cache_control :public, :must_revalidate, :no_cache, :no_store
            file = File.join(app.root, "public", "data", "#{params[:id]}.zip")
            if File.file?(file)
              send_file(file)
            else
              halt 404
            end
          end

          app.get '/dataset/:id' do
            file = File.join(app.root, "public", "data", "#{params[:id]}.zip")
            @compressed_file_size = (File.size(file).to_f / 2**20).round(2) rescue nil
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

          app.get '/donate' do
            haml :'donate', locals: { active_page: "donate" }
          end

          app.get '/donate/wall' do
            haml :'donate_wall', locals: { active_page: "wall" }
          end

          app.get '/history' do
            haml :'history', locals: { active_page: "history" }
          end

          app.get '/scribes' do
            scribes
            haml :'scribes', locals: { active_page: "scribes" }
          end

          app.get '/collection-data-managers' do
            haml :data_managers
          end

          app.get '/developers' do
            file = File.join(app.root, "public", "data", "bionomia-public-claims.csv.gz")
            @compressed_file_size = (File.size(file).to_f / 2**20).round(2) rescue nil
            haml :'developers/search', locals: { active_tab: "search" }
          end

          app.get '/developers/structured-data' do
            haml :'developers/structured_data', locals: { active_tab: "structured_data" }
          end

          app.get '/developers/code' do
            haml :'developers/code', locals: { active_tab: "code" }
          end

          app.get '/developers/parse' do
            haml :'developers/parse', locals: { active_tab: "parse" }
          end

          app.get '/help' do
            haml :help_docs
          end

          app.get '/how-it-works' do
            haml :how_it_works
          end

          app.get '/images/*.svg' do
            content_type "image/svg+xml", charset: 'utf-8'
            if !params[:splat][0].is_doi?
              halt 404
            end
            @doi = params[:splat][0]
            haml :doi_svg, layout: false
          end

          app.get '/integrations' do
            haml :integrations
          end

          app.get '/get-started' do
            haml :get_started
          end

          app.get '/on-this-day' do
            @date = DateTime.now
            if params[:date]
              @date = DateTime.parse(params[:date]) rescue @date
            end
            users = User.where(date_born_precision: "day")
                        .where("MONTH(date_born) = ? and DAY(date_born) = ?", @date.month, @date.day)
                        .order(:family)
            @pagy, @results = pagy(users)
            haml :'on_this_day/born', locals: { active_tab: "born" }
          end

          app.get '/on-this-day/died' do
            @date = DateTime.now
            if params[:date]
              @date = DateTime.parse(params[:date]) rescue @date
            end
            users = User.where(date_died_precision: "day")
                        .where("MONTH(date_died) = ? and DAY(date_died) = ?", @date.month, @date.day)
                        .order(:family)
            @pagy, @results = pagy(users)
            haml :'on_this_day/died', locals: { active_tab: "died" }
          end

          app.get '/on-this-day/collected' do
            @date = DateTime.now
            if params[:date]
              @date = DateTime.parse(params[:date]) rescue @date
            end
            occurrences = Occurrence.where.not(typeStatus: nil)
                                    .where("LOWER(typeStatus) IN ('holotype','paratype')")
                                    .where("MONTH(eventDate_processed) = ? and DAY(eventDate_processed) = ?", @date.month, @date.day)
                                    .limit(50)
            @pagy, @results = pagy(occurrences)
            haml :'on_this_day/collected', locals: { active_tab: "specimens" }
          end

          app.get '/parse' do
            @output = []
            haml :'tools/parse'
          end

          app.post '/parse' do
            @output = []
            @columns = 0
            lines = params[:names].split("\r\n")[0..999]
            lines.each_with_index do |line, index|
              item = {}
              item[index] = { original: line.dup, parsed: [] }
              parsed_names = DwcAgent.parse(line)
              parsed_names.each do |name|
                item[index][:parsed] << DwcAgent.clean(name)
              end
              cols = item[index][:parsed].size
              @columns = @columns > cols ? @columns : cols
              @output << item
            end
            haml :'tools/parse'
          end

          app.get '/reconcile' do
            haml :'tools/reconcile'
          end

          app.get '/agent.json' do
            content_type "application/json", charset: 'utf-8'
            search_agent
            format_agents.to_json
          end

          app.get '/user.json' do
            content_type "application/json", charset: 'utf-8'
            search_user
            format_users.to_json
          end

          app.get '/user.rss' do
            content_type "application/rss+xml", charset: 'utf-8'
            rss = RSS::Maker.make("2.0") do |maker|
              maker.channel.language = "en"
              maker.channel.author = "Bionomia"
              maker.channel.updated = Time.now.to_s
              maker.channel.link = "#{Settings.base_url}/user.rss"
              maker.channel.title = "Bionomia New User Feed"
              maker.channel.description = "New User Feed on #{Settings.base_url}"

              User.where(is_public: true).where.not(made_public: nil)
                  .where("made_public >= ?", 2.days.ago)
                  .find_each do |user|
                id_statement = nil
                recorded_statement = nil
                twitter = nil
                statement = nil
                if !user.twitter.nil?
                  twitter = "@#{user.twitter}"
                end
                if !user.top_family_identified.nil?
                  id_statement = "identified #{user.top_family_identified}"
                end
                if !user.top_family_recorded.nil?
                  recorded_statement = "collected #{user.top_family_recorded}"
                end
                if !user.top_family_identified.nil? || !user.top_family_recorded.nil?
                  statement = [id_statement,recorded_statement].compact.join(" and ")
                end
                maker.items.new_item do |item|
                  item.link = "#{Settings.base_url}/#{user.identifier}"
                  item.title = "#{user.fullname}"
                  item.description = "#{user.fullname} #{twitter} #{statement}".split.join(" ")
                  item.updated = user.updated
                end
              end
            end
            rss.to_s
          end

          app.get '/organization.json' do
            content_type "application/json", charset: 'utf-8'
            search_organization
            format_organizations.to_json
          end

          app.get '/taxon.json' do
            content_type "application/json", charset: 'utf-8'
            search_taxon
            format_taxon.to_json
          end

          app.get '/organizations' do
            organizations
            locals = { active_page: "organizations" }
            haml :'organizations/organizations', locals: locals
          end

          app.get '/organizations/search' do
            search_organization
            locals = { active_page: "organizations" }
            haml :'organizations/search', locals: locals
          end

          app.get '/organization/:id' do
            organization
            locals = {
              active_page: "organizations",
              active_tab: "organization-current"
            }
            haml :'organizations/organization', locals: locals
          end

          app.get '/organization/:id/past' do
            past_organization
            locals = {
              active_page: "organizations",
              active_tab: "organization-past"
            }
            haml :'organizations/organization', locals: locals
          end

          app.get '/organization/:id/metrics' do
            @year = params[:year] || nil
            organization_metrics
            locals = {
              active_page: "organizations",
              active_tab: "organization-metrics"
            }
            haml :'organizations/metrics', locals: locals
          end

          app.get '/organization/:id/citations' do
            begin
              page = (params[:page] || 1).to_i
              @pagy, @results = pagy(organization_articles, items: 10, page: page)
              locals = {
                active_page: "organizations",
                active_tab: "organization-articles"
              }
              haml :'organizations/citations', locals: locals
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/privacy' do
            haml :privacy, locals: { active_page: "privay" }
          end

          app.get '/terms-of-service' do
            haml :terms_service, locals: { active_page: "terms_service" }
          end

          app.get '/roster' do
            if params[:q] && params[:q].present?
              search_user
            else
              roster
            end
            haml :roster, locals: { active_page: "roster" }
          end

          app.get '/network' do
            haml :network
          end

          app.get '/offline' do
            haml :offline, layout: false
          end

        end

      end
    end
  end
end
