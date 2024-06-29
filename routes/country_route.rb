# encoding: utf-8

module Sinatra
  module Bionomia
    module Route
      module CountryRoute

        def self.registered(app)

          app.get '/countries' do
            @results = []
            @countries = I18nData.countries(I18n.locale)
                          .sort_alphabetical_by(&:last)
                          .group_by{|a| a[1][0]}
            haml :'countries/countries', locals: { active_page: "countries" }
          end

          app.get '/country/:country_code' do
            country_code = params[:country_code]
            @country = I18nData.countries(I18n.locale).slice(country_code.upcase).flatten
            if @country.empty?
              halt 404, haml(:oops)
            end
            @results = []
            begin
              @profile_type = "orcid"
              @action = params[:action] if ["identified","collected"].include?(params[:action])
              @family = params[:q].present? ? params[:q] : nil

              if @action || @family
                search_user_country
              else
                users = User.where("country_code LIKE ?", "%#{country_code}%")
                            .where.not(orcid: nil)
                            .order(:family)
                @pagy, @results = pagy(users, items: 30)
              end
              haml :'countries/country', locals: { active_page: "countries", active_tab: @profile_type }
            rescue
              status 404
              haml :oops
            end
          end

          app.get '/country/:country_code/wikidata' do
            country_code = params[:country_code]
            @country = I18nData.countries(I18n.locale).slice(country_code.upcase).flatten
            if @country.empty?
              halt 404, haml(:oops)
            end
            @results = []
            begin
              @profile_type = "wikidata"
              @action = params[:action] if ["identified","collected"].include?(params[:action])
              @family = params[:q].present? ? params[:q] : nil

              if @action || @family
                search_user_country
              else
                users = User.where("country_code LIKE ?", "%#{country_code}%")
                            .where.not(wikidata: nil)
                            .order(:family)
                @pagy, @results = pagy(users, items: 30)
              end
              haml :'countries/country', locals: { active_page: "countries", active_tab: @profile_type }
            rescue
              status 404
              haml :oops
            end
          end

        end

      end
    end
  end
end
