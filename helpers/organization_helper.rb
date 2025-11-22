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
          from = (page -1) * 30
          body = build_organization_query(searched_term)

          response = ::Bionomia::ElasticOrganization.new.search(from: from, size: 30, body: body)
          results = response["hits"].deep_symbolize_keys

          @pagy = Pagy::Offset.new(count: results[:total][:value], page: page, limit: 30, request: Pagy::Request.new(request))
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

        def organizations_duplicates(attribute: "grid")
          dups = Organization.select(attribute.to_sym)
                             .where.not("#{attribute}": [nil, ""])
                             .group(attribute.to_sym)
                             .having("count(*) > 1")
                             .pluck(attribute.to_sym)
                             .compact
          if params[:order] && Organization.column_names.include?(params[:order]) && ["asc", "desc"].include?(params[:sort])
            data = Organization.where("#{attribute}": dups).order("#{params[:order]} #{params[:sort]}")
          else
            data = Organization.where("#{attribute}": dups).order(attribute.to_sym)
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
                                            .sort_by {|_key, value| -value}
                                            .to_h
            @others_identified = @organization.others_specimens("identified")
                                              .sort_by {|_key, value| -value}
                                              .to_h
          end
        end

        def organization_articles
          organization_redirect("/citations")
          @organization.articles
        end

        def find_organization(id)
          organization = Organization.find_by_identifier(params[:id]) rescue nil
          if request && request.url.match(/.json$/)
            halt 404, {}.to_json if organization.nil?
          else
            halt 404 if organization.nil?
          end
          organization
        end

      end
    end
  end
end
