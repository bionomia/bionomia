# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module ProfileController

        def self.registered(app)

          app.before do
            set_session
          end

          #/auth/orcid is automatically added by OmniAuth
          app.get '/auth/orcid/callback' do
            session_data = request.env['omniauth.auth'].deep_symbolize_keys
            orcid = session_data[:uid]
            family = session_data[:info][:last_name] rescue nil
            given = session_data[:info][:first_name] rescue nil
            email = session_data[:info][:email] rescue nil
            other_names = session_data[:extra][:raw_info][:other_names].join("|") rescue nil
            country_code = session_data[:extra][:raw_info][:location]
            country = I18nData.countries(:en)[country_code] rescue nil
            description = session_data[:info][:description] rescue nil
            user = User.create_with(
                          family: family,
                          given: given,
                          orcid: session_data[:uid],
                          email: email,
                          other_names: other_names,
                          country: country,
                          country_code: country_code,
                          description: description
                        )
                       .find_or_create_by(orcid: orcid)
            organization = user.current_organization.as_json.symbolize_keys rescue nil
            user.update(visited: Time.now)
            session[:omniauth] = OpenStruct.new({ id: user.id })
            user.flush_caches
            redirect '/profile'
          end

          #/auth/zenodo is automatically added by OmniAuth
          app.get '/auth/zenodo/callback' do
            protected!
            session_data = request.env['omniauth.auth'].deep_symbolize_keys
            @user.zenodo_access_token = session_data[:info][:access_token_hash]
            @user.save
            session[:omniauth][:zenodo] = true
            redirect '/profile/settings'
          end

          app.delete '/auth/zenodo' do
            protected!
            @user.zenodo_access_token = nil
            @user.zenodo_doi = nil
            @user.zenodo_concept_doi = nil
            @user.save
            { message: "ok" }.to_json
          end

          app.get '/auth/failure' do
            session.clear
            redirect '/profile'
          end

          app.get '/logout' do
            session.clear
            redirect '/'
          end

          app.get '/profile' do
            protected!
            @stats = cache_block("#{@user.identifier}-stats") { user_stats(@user) }
            @families_identified = @user.identified_families
            @families_recorded = @user.recorded_families
            haml :'profile/overview', locals: { active_page: "profile" }
          end

          app.post '/profile/image' do
            protected!
            file_name = upload_image(app.root)
            if file_name
              @user.image_url = file_name
              @user.save
              @user.flush_caches
              { message: "ok" }.to_json
            else
              { message: "failed" }.to_json
            end
          end

          app.delete '/profile/image' do
            protected!
            if @user.image_url
              FileUtils.rm(File.join(app.root, "public", "images", "users", @user.image_url)) rescue nil
            end
            @user.image_url = nil
            @user.save
            @user.flush_caches
            { message: "ok" }.to_json
          end

          app.get '/profile/settings' do
            protected!
            haml :'profile/settings', locals: { active_page: "profile" }
          end

          app.put '/profile/settings' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            @user.wants_mail = req[:wants_mail]
            @user.save
            { message: "ok"}.to_json
          end

          app.get '/profile/specimens' do
            protected!
            create_filter

            begin
              @page = (params[:page] || 1).to_i
              @total = @user.visible_occurrences.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end

              @page = 1 if @page <= 0
              data = specimen_filters(@user).order("occurrences.typeStatus desc")
              @pagy, @results = pagy(data, items: search_size, page: @page)
              haml :'profile/specimens', locals: { active_page: "profile" }
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/profile/support' do
            protected!

            @page = (params[:page] || 1).to_i
            helped_by = @user.helped_by_counts
            @total = helped_by.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy_array(helped_by, items: search_size, page: @page)
            haml :'profile/support', locals: { active_page: "profile" }
          end

          app.get '/profile/support/:id' do
            protected!

            @helped_user = find_user(params[:id])

            @page = (params[:page] || 1).to_i
            claims_received_by = @user.claims_received_by(@helped_user.id)
            @total = claims_received_by.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(claims_received_by, items: search_size, page: @page)
            haml :'profile/support_table', locals: { active_page: "profile" }
          end

          app.get '/profile/helped' do
            protected!
            @pagy, @results = pagy_arel(@user.latest_helped, items: 15)
            haml :'profile/helped', locals: { active_page: "profile" }
          end

          app.get '/profile/messages' do
            protected!
            @user.messages_received.update_all({ read: true })
            @pagy, @results = pagy(@user.latest_messages_by_senders)
            haml :'profile/messages', locals: { active_page: "profile" }
          end

          app.put '/profile/visibility.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            @user.is_public = req[:is_public]
            if req[:is_public]
              @user.made_public = Time.now
              if !Settings.twitter.consumer_key.blank?
                vars = { user_id: @user.id }
                ::Bionomia::TwitterWorker.perform_async(vars)
              end
            end
            @user.save
            @user.update_profile
            @user.flush_caches
            { message: "ok"}.to_json
          end

          app.get '/profile/download.json' do
            protected!
            attachment "#{@user.orcid}.json"
            cache_control :public, :must_revalidate, :no_cache, :no_store
            headers.delete("Content-Length")
            content_type "application/ld+json", charset: 'utf-8'
            io = ::Bionomia::IO.new({ user: @user })
            io.jsonld_stream("all")
          end

          app.get '/profile/download.csv' do
            protected!
            records = @user.visible_occurrences
            csv_stream_headers(@user.orcid)
            io = ::Bionomia::IO.new
            body io.csv_stream_occurrences(records)
          end

          app.get '/profile/candidate-count.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            return { count: 0}.to_json if @user.family.nil?

            agent_ids = candidate_agents(@user).pluck(:id)
            count = occurrences_by_agent_ids(agent_ids)
                      .where.not(occurrence_id: @user.user_occurrences.select(:occurrence_id))
                      .pluck(:occurrence_id)
                      .uniq
                      .count
            { count: count }.to_json
          end

          app.get '/profile/message-count.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            return { count: 0}.to_json if @user.family.nil?

            count = @user.messages_received.where(read: false).count
            { count: count }.to_json
          end

          app.get '/profile/candidates.csv' do
            protected!
            content_type "text/csv", charset: 'utf-8'
            agent_ids = candidate_agents(@user).pluck(:id)
            records = occurrences_by_agent_ids(agent_ids)
                        .where
                        .not(occurrence_id: @user.user_occurrences.select(:occurrence_id))
                        .limit(5_000)
            csv_stream_headers("bionomia-candidates")
            io = ::Bionomia::IO.new
            body io.csv_stream_candidates(records)
          end

          app.get '/profile/candidates' do
            protected!

            occurrence_ids = []
            @page = (params[:page] || 1).to_i

            if @user.family.nil?
              @results = []
              @total = nil
            else
              filter_instances
              if @agent
                id_scores = [{ id: @agent.id, score: 3 }]
                occurrence_ids = occurrences_by_score(id_scores, @user)
              else
                id_scores = candidate_agents(@user)
                occurrence_ids = occurrences_by_score(id_scores, @user)
              end

              if !id_scores.empty?
                occurrence_ids = occurrences_by_score(id_scores, @user)
              end

              specimen_pager(occurrence_ids.uniq)
            end

            haml :'profile/candidates', locals: { active_page: "profile" }
          end

          app.post '/profile/advanced-search' do
            protected!

            @agent_results = []
            @dataset_results = []
            @taxon_results = []
            @agent, @dataset, @taxon, @kingdom = nil

            if params[:datasetKey] && !params[:datasetKey].blank?
              @dataset = Dataset.find_by_datasetKey(params[:datasetKey]) rescue nil
            elsif params[:dataset]
              search_dataset
              @dataset_results = format_datasets
            end

            if params[:agent_id] && !params[:agent_id].blank?
              @agent = Agent.find(params[:agent_id]) rescue nil
            elsif params[:agent] && !params[:agent].blank?
              search_agent({ item_size: 75 })
              @agent_results = format_agents
            end

            if params[:taxon_id] && !params[:taxon_id].blank?
              @taxon = Taxon.find(params[:taxon_id]) rescue nil
            elsif params[:taxon]
              search_taxon
              @taxon_results = format_taxon
            end

            if params[:kingdom] && !params[:kingdom].blank? && Taxon.valid_kingdom?(params[:kingdom])
              @kingdom = params[:kingdom]
            end

            haml :'profile/advanced_search', locals: { active_page: "profile" }
          end

          app.get '/profile/advanced-search' do
            protected!
            filter_instances
            haml :'profile/advanced_search', locals: { active_page: "profile" }
          end

          app.get '/profile/upload' do
            protected!
            haml :'profile/upload', locals: { active_page: "profile" }
          end

          app.post '/profile/upload-result' do
            protected!
            begin
              upload_file(user_id: @user.id, created_by: @user.id)
            rescue => e
              flash.now[:error] = e.message
            end
            haml :'profile/upload_result', locals: { active_page: "profile" }
          end

          app.get '/profile/ignored' do
            protected!

            @page = (params[:page] || 1).to_i
            hidden_occurrences = @user.hidden_occurrences
            @total = hidden_occurrences.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(hidden_occurrences, items: search_size, page: @page)
            haml :'profile/ignored', locals: { active_page: "profile", active_tab: "ignored" }
          end

          app.get '/profile/citations' do
            protected!
            page = (params[:page] || 1).to_i
            @pagy, @results = pagy(@user.articles_citing_specimens, items: 10, page: page)
            haml :'profile/citations', locals: { active_page: "profile" }
          end

          app.get '/profile/citation/*' do
            protected!
            article_from_param
            cited_specimens = @user.cited_specimens_by_article(@article.id)
            @total = cited_specimens.count
            if @total == 0
              halt 404
            end

            @page = (params[:page] || 1).to_i

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @pagy, @results = pagy(cited_specimens, items: search_size, page: @page)
            haml :'profile/citation', locals: { active_page: "profile" }
          end

          app.get '/profile/co-collectors' do
            protected!
            page = (params[:page] || 1).to_i
            @pagy, @results = pagy(@user.recorded_with, page: page)
            haml :'profile/co_collectors', locals: { active_page: "profile", active_tab: "co_collectors" }
          end

          app.get '/profile/co-collector/:id' do
            protected!

            @co_collector = find_user(@params[:id])

            @page = (params[:page] || 1).to_i
            co_collections = @user.recordings_with(@co_collector)
            @total = co_collections.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0
            @pagy, @results = pagy(co_collections, items: search_size, page: @page)
            haml :'profile/co_collector_specimens', locals: { active_page: "profile", active_tab: "co_collectors" }
          end

          app.post '/profile/message.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            m = Message.new
            m.user_id = @user.id
            recipient = find_user(req[:recipient_identifier])
            m.recipient_id = recipient.id
            m.save
            { message: "ok", occurrence_id: params[:occurrence_id] }.to_json
          end

          app.get '/profile/refresh.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            @user.update_profile
            @user.flush_caches
            { message: "ok" }.to_json
          end

          app.delete '/profile/destroy' do
            protected!
            @user.flush_caches
            @user.destroy
            session.clear
            redirect '/'
          end

        end

      end
    end
  end
end
