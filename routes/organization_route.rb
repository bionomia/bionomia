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
              @year = params[:year] || nil
              organization_metrics
              locals = {
                active_page: "organizations",
                active_tab: "organization-metrics"
              }
              haml :'organizations/metrics', locals: locals
            end

            get '/:id/citations' do
              page = (params[:page] || 1).to_i
              data = organization_articles.to_a
              @pagy, @results = pagy_array(data, count: data.size, items: 10, page: page)
              locals = {
                active_page: "organizations",
                active_tab: "organization-articles"
              }
              haml :'organizations/citations', locals: locals
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
