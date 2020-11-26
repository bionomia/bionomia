# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module TaxonController

        def self.registered(app)

          app.get '/taxon.json' do
            content_type "application/json", charset: 'utf-8'
            search_taxon
            format_taxon.to_json
          end

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

          app.get '/taxon/:taxon' do
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

          app.get '/taxon/:taxon/agents' do
            taxon_agents
            locals = {
              active_page: "taxa",
              active_tab: "agents",
              active_subtab: "default"
            }
            haml :'taxa/agents', locals: locals
          end

          app.get '/taxon/:taxon/agents/counts' do
            taxon_agents_counts
            locals = {
              active_page: "taxa",
              active_tab: "agents",
              active_subtab: "counts"
            }
            haml :'taxa/agents_counts', locals: locals
          end

          app.get '/taxon/:taxon/agents/unclaimed' do
            taxon_agents_unclaimed
            locals = {
              active_page: "taxa",
              active_tab: "agents",
              active_subtab: "unclaimed"
            }
            haml :'taxa/agents_unclaimed', locals: locals
          end

        end

      end
    end
  end
end
