# encoding: utf-8

module Sinatra
  module Bionomia
    module Route
      module OrganizationRoute

        def self.registered(app)

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

          app.namespace '/organization' do

            get '.json' do
              content_type "application/json", charset: 'utf-8'
              search_organization
              format_organizations.to_json
            end

            get '/:id' do
              organization
              locals = {
                active_page: "organizations",
                active_tab: "organization-current"
              }
              haml :'organizations/organization', locals: locals
            end

            get '/:id/past' do
              past_organization
              locals = {
                active_page: "organizations",
                active_tab: "organization-past"
              }
              haml :'organizations/organization', locals: locals
            end

            get '/:id/metrics' do
              organization
              locals = {
                active_page: "organizations",
                active_tab: "organization-metrics"
              }
              haml :'organizations/under_repair', locals: locals
=begin
              @year = params[:year] || nil
              organization_redirect("/metrics")

              if Organization::METRICS_YEAR_RANGE.to_a.include?(@year.to_i)
                @others_recorded = @organization.others_specimens_by_year("recorded", @year)
                @others_identified = @organization.others_specimens_by_year("identified", @year)
              else
                @others_recorded = cache_block("organization-#{@organization.id}-recorded") { 
                  @organization.others_specimens("recorded")
                  } 
                @others_identified = cache_block("organization-#{@organization.id}-identified") {
                  @organization.others_specimens("identified")
                  }
              end
              haml :'organizations/metrics', locals: locals
=end
            end

            get '/:id/citations' do
              organization
              locals = {
                active_page: "organizations",
                active_tab: "organization-articles"
              }
              haml :'organizations/under_repair', locals: locals
=begin
              data = organization_articles.to_a
              @pagy, @results = pagy_array(data, count: data.size, limit: 10, page: page)
              haml :'organizations/citations', locals: locals
=end
            end

            get '/:id/refresh.json' do
              content_type "application/json", charset: 'utf-8'
              protected!
              organization = find_organization(params[:id])
              organization.update_wikidata
              { message: "ok" }.to_json
            end

          end

        end

      end
    end
  end
end
