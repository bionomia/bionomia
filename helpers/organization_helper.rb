# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module OrganizationHelper

        def search_organization
          searched_term = params[:q]
          @results = []
          return if !searched_term.present?

          page = (params[:page] || 1).to_i

          client = Elasticsearch::Client.new(
            url: Settings.elastic.server,
            request_timeout: 5*60,
            retry_on_failure: true,
            reload_on_failure: true,
            reload_connections: 1_000,
            adapter: :typhoeus
          )
          body = build_organization_query(searched_term)
          from = (page -1) * 30

          response = client.search index: Settings.elastic.organization_index, from: from, size: 30, body: body
          results = response["hits"].deep_symbolize_keys

          @pagy = Pagy.new(count: results[:total][:value], items: 30, page: page)
          @results = results[:hits]
        end

        def organizations
          if params[:order] && Organization.column_names.include?(params[:order]) && ["asc", "desc"].include?(params[:sort])
            data = Organization.active_user_organizations.order("#{params[:order]} #{params[:sort]}")
          else
            data = Organization.active_user_organizations.order(:name)
          end
          @pagy, @results = pagy(data)
        end

        def organization_redirect(path = "")
          @organization = Organization.find_by_identifier(params[:id]) rescue nil
          if @organization.nil?
            halt 404
          end
          if !@organization.wikidata.nil? && params[:id] != @organization.wikidata
            redirect "/organization/#{@organization.wikidata}#{path}"
          end
        end

        def organization
          organization_redirect
          @pagy, @results = pagy(@organization.active_users.order(:family))
        end

        def past_organization
          organization_redirect("/past")
          @pagy, @results = pagy(@organization.inactive_users.order(:family))
        end

        def organization_metrics
          organization_redirect("/metrics")
          if Organization::METRICS_YEAR_RANGE.to_a.include?(@year.to_i)
            @others_recorded = @organization.others_specimens_by_year("recorded", @year)
            @others_identified = @organization.others_specimens_by_year("identified", @year)
          else
            @others_recorded = @organization.others_specimens("recorded")
            @others_identified = @organization.others_specimens("identified")
          end
        end

        def organization_articles
          organization_redirect("/citations")
          @organization.articles
        end

      end
    end
  end
end
