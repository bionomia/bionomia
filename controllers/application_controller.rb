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
            haml_i18n :about, locals: { active_page: "about" }
          end

          app.get '/acknowledgments' do
            haml :acknowledgments, locals: { active_page: "acknowledgments" }
          end

          app.get '/donate' do
            haml :'donate', locals: { active_page: "donate" }
          end

          app.get '/donate/wall' do
            haml :'donate_wall', locals: { active_page: "wall" }
          end

          app.get '/history' do
            haml_i18n :'history', locals: { active_page: "history" }
          end

          app.get '/scribes' do
            scribes
            haml :'scribes', locals: { active_page: "scribes" }
          end

          app.get '/collection-data-managers' do
            haml_i18n :data_managers
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
            haml_i18n :help_docs
          end

          app.get '/how-it-works' do
            haml_i18n :how_it_works
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
            haml_i18n :integrations
          end

          app.get '/get-started' do
            haml_i18n :get_started
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

          app.get '/privacy' do
            haml_i18n :privacy, locals: { active_page: "privacy" }
          end

          app.get '/terms-of-service' do
            haml_i18n :terms_service, locals: { active_page: "terms_service" }
          end

          app.get '/roster' do
            if params[:q] && params[:q].present?
              search_user
            else
              roster
            end
            haml :roster, locals: { active_page: "roster" }
          end

          app.get '/offline' do
            haml :offline, layout: false
          end

          app.get '/workshops' do
            haml :workshops, locals: { active_page: "workshops" }
          end

        end

      end
    end
  end
end
