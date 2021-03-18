# encoding: utf-8

class Hash
  def without(*keys)
    cpy = self.dup
    keys.each { |key| cpy.delete(key) }
    cpy
  end
end

module Sinatra
  module Bionomia
    module Controller
      module UserController

        def self.registered(app)

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

          app.get '/:id/specimens.json' do
            content_type "application/ld+json", charset: 'utf-8'
            if !params[:id].is_orcid? && !params[:id].is_wiki_id?
              halt 404, {}.to_json
            end

            check_redirect
            viewed_user = find_user(params[:id])

            if viewed_user.orcid && !viewed_user.is_public?
              halt 404, {}.to_json
            end

            cache_control :public, :must_revalidate, :no_cache, :no_store
            headers.delete("Content-Length")
            begin
              io = ::Bionomia::IO.new({ user: viewed_user, params: params, request: request })
              io.jsonld_stream("paged")
            rescue
              halt 404, {}.to_json
            end
          end

          app.get '/:id/specimens.csv' do
            content_type "text/csv", charset: 'utf-8'
            if !params[:id].is_orcid? && !params[:id].is_wiki_id?
              halt 404, [].to_csv
            end

            check_redirect
            @viewed_user = find_user(params[:id])

            if @viewed_user.orcid && !@viewed_user.is_public?
              halt 404, [].to_csv
            end

            begin
              csv_stream_headers
              records = @viewed_user.visible_occurrences
              io = ::Bionomia::IO.new
              body io.csv_stream_occurrences(records)
            rescue
              halt 404, [].to_csv
            end
          end

          app.get '/:id' do
            check_identifier
            check_redirect
            @viewed_user = find_user(params[:id])
            check_user_public
            @stats = cache_block("#{@viewed_user.identifier}-stats") { user_stats(@viewed_user) }
            haml :'public/overview', locals: { active_page: "roster" }
          end

          app.get '/:id/specialties' do
            check_identifier
            check_redirect
            @viewed_user = find_user(params[:id])
            check_user_public
            @families_identified, @families_recorded = [], []
            if @viewed_user.is_public?
              @families_identified = @viewed_user.identified_families
              @families_recorded = @viewed_user.recorded_families
            end
            haml :'public/specialties', locals: { active_page: "roster" }
          end

          app.get '/:id/specimens' do
            check_identifier
            check_redirect
            @viewed_user = find_user(params[:id])
            check_user_public
            create_filter

            begin
              @pagy, @results = {}, []
              if @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                data = specimen_filters(@viewed_user).order("occurrences.typeStatus desc")
                @pagy, @results = pagy(data, page: page)
              end
              locals = {
                active_page: "roster",
                active_tab: "specimens"
              }
              haml :'public/specimens', locals: locals
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/:id/support' do
            check_identifier
            check_redirect
            @viewed_user = find_user(params[:id])
            check_user_public

            begin
              @page = (params[:page] || 1).to_i
              helped_by = @viewed_user.helped_by_counts
              @total = helped_by.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end

              @page = 1 if @page <= 0

              @pagy, @results = pagy_array(helped_by, items: search_size, page: @page)
              locals = {
                active_page: "roster",
                active_tab: "support"
              }
              haml :'public/support', locals: locals
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/:id/citations' do
            check_identifier
            check_redirect
            @viewed_user = find_user(params[:id])
            check_user_public

            begin
              @pagy, @results = {}, []
              if @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                @stats = cache_block("#{@viewed_user.identifier}-stats") { user_stats(@viewed_user) }
                @pagy, @results = pagy(@viewed_user.articles_citing_specimens, items: 10, page: page)
              end
              haml :'public/citations', locals: { active_page: "roster" }
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/:id/citation/:article_id' do
            check_identifier
            check_redirect
            @viewed_user = find_user(params[:id])
            check_user_public

            @article = Article.find(params[:article_id]) rescue nil
            if !@article
              halt 404, hamls(:oops)
            end

            begin
              @pagy, @results = {}, []
              if @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                @pagy, @results = pagy(@viewed_user.cited_specimens_by_article(@article.id), page: page)
              end
              haml :'public/citation', locals: { active_page: "roster" }
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/:id/co-collectors' do
            check_identifier
            check_redirect
            @viewed_user = find_user(params[:id])
            check_user_public

            begin
              @pagy, @results = {}, []
              if @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                @pagy, @results = pagy(@viewed_user.recorded_with, page: page)
              end
              locals = {
                active_page: "roster",
                active_tab: "co_collectors"
              }
              haml :'public/co_collectors', locals: locals
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/:id/identified-for' do
            check_identifier
            check_redirect
            @viewed_user = find_user(params[:id])
            check_user_public

            begin
              @pagy, @results = {}, []
              if @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                @pagy, @results = pagy(@viewed_user.identified_for, page: page)
              end
              locals = {
                active_page: "roster",
                active_tab: "identified_for"
              }
              haml :'public/identified_for', locals: locals
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/:id/identifications-by' do
            check_identifier
            check_redirect
            @viewed_user = find_user(params[:id])
            check_user_public

            begin
              @pagy, @results = {}, []
              if @viewed_user.is_public?
                page = (params[:page] || 1).to_i
                @pagy, @results = pagy(@viewed_user.identified_by, page: page)
              end
              locals = {
                active_page: "roster",
                active_tab: "identifications_by"
              }
              haml :'public/identifications_by', locals: locals
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/:id/deposited-at' do
            check_identifier
            check_redirect
            @viewed_user = find_user(params[:id])
            check_user_public
            @recordings_at, @identifications_at = [], []
            if @viewed_user.is_public?
              @recordings_at = @viewed_user.recordings_deposited_at
              @identifications_at = @viewed_user.identifications_deposited_at
            end
            haml :'public/deposited_at', locals: { active_page: "roster" }
          end

          app.get '/:id/helped' do
            check_identifier
            check_redirect
            @viewed_user = find_user(params[:id])
            halt 404 if !@viewed_user.orcid
            @stats = cache_block("#{@viewed_user.identifier}-stats") { user_stats(@viewed_user) }
            page = (params[:page] || 1).to_i
            @pagy, @results = pagy_array(@viewed_user.helped, items: 30, page: page)
            haml :'public/helped', locals: { active_page: "roster" }
          end

          app.get '/:id/progress.json' do
            content_type "application/json"
            expires 0, :no_cache, :must_revalidate

            viewed_user = find_user(params[:id])
            claimed = viewed_user.all_occurrences_count
            agent_ids = candidate_agents(viewed_user).pluck(:id)
            unclaimed = occurrences_by_agent_ids(agent_ids)
                          .where.not({ occurrence_id: viewed_user.user_occurrences.select(:occurrence_id) })
                          .distinct
                          .count(:occurrence_id)
            { claimed: claimed, unclaimed: unclaimed }.to_json
          end

          app.get '/:id/refresh.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            user = find_user(params[:id])
            user.update_profile
            user.flush_caches
            { message: "ok" }.to_json
          end

          app.get '/:id/refresh-stats.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            user = find_user(params[:id])
            user.flush_caches
            user.refresh_search
            { message: "ok" }.to_json
          end

        end

      end
    end
  end
end
