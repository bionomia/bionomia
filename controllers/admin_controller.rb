# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module AdminController

        def self.registered(app)

          app.get '/admin' do
            admin_protected!
            haml :'admin/welcome', locals: { active_page: "administration" }
          end

          app.get '/admin/articles/check-new.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'

            params = {
              max_size: 100_000_000,
              first_page_only: true
            }
            tracker = ::Bionomia::GbifTracker.new(params)
            tracker.create_package_records
            { message: "ok" }.to_json
          end

          app.get '/admin/articles' do
            admin_protected!
            @pagy, @results = pagy(Article.order(created: :desc), items: 50)
            haml :'admin/articles', locals: { active_page: "administration" }
          end

          app.get '/admin/article/:id/process.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'

            vars = {
              article_id: params[:id]
            }

            ::Bionomia::ArticleWorker.perform_async(vars)
            { message: "ok" }.to_json
          end

          app.get '/admin/article/:id' do
            admin_protected!
            @article = Article.find(params[:id]) rescue nil
            if @article.nil?
              halt 404
            end
            haml :'admin/article', locals: { active_page: "administration" }
          end

          app.post '/admin/article/:id' do
            admin_protected!
            @article = Article.find(params[:id]) rescue nil
            if @article.nil?
              halt 404
            end
            data = { doi: @article.doi }
            @article.update(data)
            flash.next[:updated] = true
            redirect "/admin/article/#{@article.id}"
          end

          app.delete '/admin/article/:id' do
            admin_protected!
            article = Article.find(params[:id]) rescue nil
            if article.nil?
              halt 404
            end
            title = article.citation.dup
            article.destroy
            flash.next[:destroyed] = title
            redirect "/admin/articles"
          end

          app.get '/admin/datasets' do
            admin_protected!
            sort = params[:sort] || nil
            order = params[:order] || nil
            datasets
            locals = {
              active_page: "administration",
              sort: sort, order: order
            }
            haml :'admin/datasets', locals: locals
          end

          app.get '/admin/dataset/frictionless.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'

            vars = {
              uuid: params[:datasetKey],
              output_directory: File.join(File.dirname(__FILE__), "..", "public", "data")
            }

            ::Bionomia::FrictionlessDataWorker.perform_async(vars)
            { message: "ok" }.to_json
          end

          app.get '/admin/dataset/refresh.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'

            dataset = ::Bionomia::GbifDataset.new
            dataset.process_dataset(params[:datasetKey])
            { message: "ok" }.to_json
          end

          app.get '/admin/dataset/:id' do
            admin_protected!
            @dataset = Dataset.find_by_datasetKey(params[:id]) rescue nil
            if @dataset.nil?
              halt 404
            end
            haml :'admin/dataset', locals: { active_page: "administration" }
          end

          app.post '/admin/dataset/:id' do
            admin_protected!
            @dataset = Dataset.find(params[:id]) rescue nil
            if @dataset.nil?
              halt 404
            end
            title = params[:title].blank? ? nil : params[:title]
            doi = params[:doi].blank? ? nil : params[:doi]
            license = params[:license].blank? ? nil : params[:license]
            image_url = params[:image_url].blank? ? nil : params[:image_url]
            description = params[:description].blank? ? nil : params[:description]
            data = {
              title: title,
              doi: doi,
              license: license,
              image_url: image_url,
              description: description,
            }
            @dataset.update(data)
            flash.next[:updated] = true
            redirect "/admin/dataset/#{@dataset.datasetKey}"
          end

          app.delete '/admin/dataset/:id' do
            admin_protected!
            dataset = Dataset.find(params[:id]) rescue nil
            if dataset.nil?
              halt 404
            end
            title = dataset.title.dup
            dataset.destroy
            flash.next[:destroyed] = title
            redirect "/admin/datasets"
          end

          app.get '/admin/datasets/search' do
            admin_protected!
            search_dataset
            locals = { active_page: "administration" }
            haml :'admin/datasets_search', locals: locals
          end

          app.get '/admin/organizations' do
            admin_protected!
            sort = params[:sort] || nil
            order = params[:order] || nil
            organizations
            locals = {
              active_page: "administration",
              sort: sort, order: order
            }
            haml :'admin/organizations', locals: locals
          end

          app.get '/admin/organizations/search' do
            admin_protected!
            search_organization
            locals = { active_page: "administration" }
            haml :'admin/organizations_search', locals: locals
          end

          app.get '/admin/organization/:organization_id/refresh.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'

            organization = Organization.find(params[:organization_id])
            organization.update_wikidata
            { message: "ok" }.to_json
          end

          app.get '/admin/organization/:id' do
            admin_protected!
            @organization = Organization.find(params[:id]) rescue nil
            if @organization.nil?
              halt 404
            end
            haml :'admin/organization', locals: { active_page: "administration" }
          end

          app.post '/admin/organization/:id' do
            admin_protected!
            @organization = Organization.find(params[:id]) rescue nil
            if @organization.nil?
              halt 404
            end
            name = params[:name].blank? ? nil : params[:name]
            address = params[:address].blank? ? nil : params[:address]
            isni = params[:isni].blank? ? nil : params[:isni]
            grid = params[:grid].blank? ? nil : params[:grid]
            ringgold = params[:ringgold].blank? ? nil : params[:ringgold]
            wikidata = params[:wikidata].blank? ? nil : params[:wikidata]
            institution_codes = params[:institution_codes].empty? ? nil : params[:institution_codes].split("|").map(&:strip)
            data = {
              name: name,
              address: address,
              isni: isni,
              grid: grid,
              ringgold: ringgold,
              wikidata: wikidata,
              institution_codes: institution_codes
            }
            wikidata_lib = ::Bionomia::WikidataSearch.new
            code = wikidata || grid || ringgold
            wiki = wikidata_lib.institution_wikidata(code)
            data.merge!(wiki) if wiki
            @organization.update(data)
            flash.next[:updated] = true
            redirect "/admin/organization/#{params[:id]}"
          end

          app.delete '/admin/organization/:id' do
            admin_protected!
            organization = Organization.find(params[:id]) rescue nil
            if organization.nil?
              halt 404
            end
            title = organization.name.dup
            organization.destroy
            flash.next[:destroyed] = title
            redirect "/admin/organizations"
          end

          app.get '/admin/users' do
            admin_protected!
            sort = params[:sort] || nil
            order = params[:order] || nil
            admin_roster
            locals = {
              active_page: "administration",
              sort: sort, order: order
            }
            haml :'admin/roster', locals: locals
          end

          app.get '/admin/users/search' do
            admin_protected!
            search_user
            haml :'admin/user_search', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])
            @stats = cache_block("#{@admin_user.identifier}-stats") { user_stats(@admin_user) }
            @families_identified = @admin_user.identified_families
            @families_recorded = @admin_user.recorded_families
            haml :'admin/overview', locals: { active_page: "administration" }
          end

          app.put '/admin/user/:id/deceased' do
            admin_protected!
            admin_user = User.find(params[:id])
            if !admin_user.orcid.nil?
              old_orcid = admin_user.orcid.dup
              admin_user.orcid = nil
              admin_user.wikidata = params[:wikidata]
              admin_user.save
              admin_user.reload
              admin_user.update_profile
              DestroyedUser.create(identifier: old_orcid, redirect_to: params[:wikidata])
              admin_user.flush_caches
              flash.next[:updated] = true
            end
            redirect "/admin/user/#{admin_user.identifier}/settings"
          end

          app.delete '/admin/user/:id' do
            admin_protected!
            @admin_user = User.find(params[:id]) rescue nil
            if @admin_user.nil?
              halt 404
            end
            name = @admin_user.fullname.dup
            @admin_user.destroy
            @admin_user.flush_caches
            flash.next[:destroyed] = name
            redirect '/admin/users'
          end

          app.post '/admin/user/:id/image' do
            admin_protected!
            @admin_user = find_user(params[:id])
            file_name = upload_image(app.root)
            if file_name
              @admin_user.image_url = file_name
              @admin_user.save
              @admin_user.flush_caches
              { message: "ok" }.to_json
            else
              { message: "failed" }.to_json
            end
          end

          app.delete '/admin/user/:id/image' do
            admin_protected!
            @admin_user = find_user(params[:id])
            if @admin_user.image_url
              FileUtils.rm(File.join(app.root, "public", "images", "users", @admin_user.image_url)) rescue nil
            end
            @admin_user.image_url = nil
            @admin_user.save
            @admin_user.flush_caches
            { message: "ok" }.to_json
          end

          app.get '/admin/user/:id/settings' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])
            haml :'admin/settings', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/specimens' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])

            range = nil
            if params[:start_year] || params[:end_year]
              range = [params[:start_year], params[:end_year]].join(" – ")
            end

            country = I18nData.countries(:en)[params[:country_code]] rescue nil
            family = params[:family] rescue nil
            @filter = {
              action: params[:action],
              country: country,
              range: range,
              family: family
            }.compact

            begin
              @page = (params[:page] || 1).to_i
              @total = @admin_user.visible_occurrences.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end

              @page = 1 if @page <= 0
              data = specimen_filters(@admin_user).order("occurrences.typeStatus desc")
              @pagy, @results = pagy(data, items: search_size, page: @page)
              haml :'admin/specimens', locals: { active_page: "administration" }
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/admin/user/:id/specimens.json' do
            admin_protected!
            content_type "application/ld+json", charset: 'utf-8'
            admin_user = find_user(params[:id])
            attachment "#{admin_user.identifier}.json"
            cache_control :no_cache
            headers.delete("Content-Length")
            io = ::Bionomia::IO.new({ user: admin_user })
            io.jsonld_stream("all")
          end

          app.get '/admin/user/:id/message-count.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            admin_user = find_user(params[:id])
            return { count: 0}.to_json if admin_user.family.nil?

            count = admin_user.messages_received.where(read: false).count
            { count: count }.to_json
          end

          app.get '/admin/user/:id/specimens.csv' do
            admin_protected!
            content_type "text/csv", charset: 'utf-8'
            admin_user = find_user(params[:id])
            records = admin_user.visible_occurrences
            csv_stream_headers
            io = ::Bionomia::IO.new
            body io.csv_stream_occurrences(records)
          end

          app.get '/admin/user/:id/support' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])

            @page = (params[:page] || 1).to_i
            helped_by = @admin_user.helped_by_counts
            @total = helped_by.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy_array(helped_by, items: search_size, page: @page)
            haml :'admin/support', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/support/:id2' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])
            @helped_user = find_user(params[:id2])

            @page = (params[:page] || 1).to_i
            received_by = @admin_user.claims_received_by(@helped_user.id)
            @total = received_by.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(received_by, items: search_size, page: @page)
            haml :'admin/support_table', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/helped' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])

            @pagy, @results = pagy_arel(@admin_user.latest_helped, items: 15)
            haml :'admin/helped', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/messages' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])

            @pagy, @results = pagy(@admin_user.latest_messages_by_senders)
            haml :'admin/messages', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/candidates.csv' do
            protected!
            content_type "text/csv", charset: 'utf-8'
            @admin_user = find_user(params[:id])
            agent_ids = candidate_agents(@admin_user).pluck(:id)
            records = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: @admin_user.user_occurrences.select(:occurrence_id))
            csv_stream_headers
            io = ::Bionomia::IO.new
            body io.csv_stream_candidates(records)
          end

          app.get '/admin/user/:id/candidates' do
            admin_protected!
            check_redirect
            occurrence_ids = []
            @page = (params[:page] || 1).to_i

            @admin_user = find_user(params[:id])

            if @admin_user.family.nil?
              @results = []
              @total = nil
            else
              @dataset, @agent, @taxon = nil
              if params[:datasetKey]
                @dataset = Dataset.find_by_datasetKey(params[:datasetKey]) rescue nil
              end
              if params[:agent_id]
                @agent = Agent.find(params[:agent_id]) rescue nil
              end
              if params[:taxon_id]
                @taxon = Taxon.find(params[:taxon_id]) rescue nil
              end

              if @agent
                id_scores = [{ id: @agent.id, score: 3 }]
                occurrence_ids = occurrences_by_score(id_scores, @admin_user)
              else
                id_scores = candidate_agents(@admin_user)
                occurrence_ids = occurrences_by_score(id_scores, @admin_user)
              end

              specimen_pager(occurrence_ids.uniq)
            end

            bulk_error_message = flash.now[:error] ? flash.now[:error] : ""
            locals = {
              active_page: "administration",
              bulk_error: bulk_error_message
            }
            haml :'admin/candidates', locals: locals
          end

          app.post '/admin/user/:id/advanced-search' do
            admin_protected!

            @admin_user = find_user(params[:id])

            @agent_results = []
            @dataset_results = []
            @taxon_results = []
            @agent = nil
            @dataset = nil
            @taxon = nil

            if params[:datasetKey]
              @dataset = Dataset.find_by_datasetKey(params[:datasetKey]).title rescue nil
            elsif params[:dataset]
              search_dataset
              @dataset_results = format_datasets
            end

            if params[:agent_id]
              @agent = Agent.find(params[:agent_id]).fullname_reverse rescue nil
            elsif params[:agent]
              search_agent({ item_size: 75 })
              @agent_results = format_agents
            end

            if params[:taxon_id]
              @taxon = Taxon.find(params[:taxon_id]).family rescue nil
            elsif params[:taxon]
              search_taxon
              @taxon_results = format_taxon
            end

            haml :'admin/advanced_search', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/advanced-search' do
            admin_protected!

            @admin_user = find_user(params[:id])

            if params[:datasetKey]
              @dataset = Dataset.find_by_datasetKey(params[:datasetKey]).title rescue nil
            end
            if params[:agent_id]
              @agent = Agent.find(params[:agent_id]).fullname_reverse rescue nil
            end
            if params[:taxon_id]
              @taxon = Taxon.find(params[:taxon_id]).family rescue nil
            end
            haml :'admin/advanced_search', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/candidate-count.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            admin_user = find_user(params[:id])
            return { count: 0 }.to_json if admin_user.family.nil?

            agent_ids = candidate_agents(admin_user).pluck(:id)
            count = occurrences_by_agent_ids(agent_ids)
                      .where.not(occurrence_id: admin_user.user_occurrences.select(:occurrence_id))
                      .pluck(:occurrence_id)
                      .uniq
                      .count
            { count: count }.to_json
          end

          app.post '/admin/user/:id/candidates/agent/:agent_id/bulk-claim' do
            admin_protected!
            check_redirect
            user = find_user(params[:id])
            agent = Agent.find(params[:agent_id])
            begin
              user.bulk_claim(agent: agent, conditions: params[:conditions], ignore: params[:ignore])
            rescue ArgumentError => e
              flash.next[:error] = "#{e.message}"
            end
            redirect "/admin/user/#{params[:id]}/candidates?agent_id=#{params[:agent_id]}"
          end

          app.get '/admin/user/:id/ignored' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])
            @page = (params[:page] || 1).to_i
            @total = @admin_user.hidden_occurrences.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(@admin_user.hidden_occurrences, items: search_size, page: @page)
            haml :'admin/ignored', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/citations' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])
            page = (params[:page] || 1).to_i
            cited = @admin_user.articles_citing_specimens
            @total = cited.count

            @pagy, @results = pagy(cited, page: page)
            haml :'admin/citations', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/citation/:article_id' do
            admin_protected!
            check_redirect
            @admin_user = find_user(params[:id])
            @article = Article.find(params[:article_id])
            if !@article
              halt 404
            end

            @page = (params[:page] || 1).to_i
            cited_specimens = @admin_user.cited_specimens_by_article(@article.id)
            @total = cited_specimens.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(cited_specimens, page: @page, items: search_size)
            haml :'admin/citation', locals: { active_page: "administration" }
          end

          app.get '/admin/user/:id/refresh.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            admin_user = find_user(params[:id])
            admin_user.update_profile
            admin_user.flush_caches
            { message: "ok" }.to_json
          end

          app.put '/admin/user/:id/visibility.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            admin_user = find_user(params[:id])
            admin_user.is_public = req[:is_public]
            if req[:is_public]
              admin_user.made_public = Time.now
              if !Settings.twitter.consumer_key.blank?
                vars = { user_id: admin_user.id }
                ::Bionomia::TwitterWorker.perform_async(vars)
              end
            end
            admin_user.save
            admin_user.update_profile
            admin_user.flush_caches
            { message: "ok" }.to_json
          end

          app.post '/admin/user-occurrence/bulk.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            action = req[:action] rescue nil
            visible = req[:visible] rescue true
            occurrence_ids = req[:occurrence_ids].split(",")
            if !visible
              UserOccurrence.where(occurrence_id: occurrence_ids)
                            .where(user_id: req[:user_id].to_i)
                            .destroy_all
            end
            data = occurrence_ids.map{|o| {
                user_id: req[:user_id].to_i,
                occurrence_id: o.to_i,
                created_by: @user.id,
                action: action,
                visible: visible
              }
            }
            UserOccurrence.import data, batch_size: 250, validate: false, on_duplicate_key_ignore: true
            { message: "ok" }.to_json
          end

          app.post '/admin/user-occurrence/:occurrence_id.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            action = req[:action] rescue nil
            visible = req[:visible] rescue true
            uo = UserOccurrence.new
            uo.user_id = req[:user_id].to_i
            uo.occurrence_id = params[:occurrence_id].to_i
            uo.created_by = @user.id
            uo.action = action
            uo.visible = visible
            uo.save
            { message: "ok", id: uo.id }.to_json
          end

          app.put '/admin/user-occurrence/bulk.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            occurrence_ids = req[:occurrence_ids].split(",")
            visible = req[:visible] rescue true
            data = { action: req[:action], visible: visible, created_by: @user.id }
            UserOccurrence.where(id: occurrence_ids, user_id: req[:user_id].to_i)
                          .update_all(data)
            { message: "ok" }.to_json
          end

          app.put '/admin/user-occurrence/:id.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            uo = UserOccurrence.find_by(id: params[:id].to_i, user_id: req[:user_id].to_i)
            uo.action = req[:action]
            uo.visible = true
            uo.created_by = @user.id
            uo.save
            { message: "ok" }.to_json
          end

          app.delete '/admin/user-occurrence/bulk.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            ids = req[:ids].split(",")
            UserOccurrence.where(id: ids, user_id: req[:user_id].to_i)
                          .delete_all
            { message: "ok" }.to_json
          end

          app.delete '/admin/user-occurrence/:id.json' do
            admin_protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            UserOccurrence.where(id: params[:id].to_i, user_id: req[:user_id].to_i)
                          .delete_all
            { message: "ok" }.to_json
          end

        end

      end
    end
  end
end
