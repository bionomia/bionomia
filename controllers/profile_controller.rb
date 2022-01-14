# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module ProfileController

        def self.registered(app)

          app.get '/logout' do
            session.clear
            redirect '/'
          end

          # /auth is automatically added by OmniAuth
          app.namespace '/auth' do
            get '/orcid/callback' do
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
                            orcid: orcid,
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
              redirect '/profile'
            end

            get '/zenodo/callback' do
              protected!
              session_data = request.env['omniauth.auth'].deep_symbolize_keys
              @user.zenodo_access_token = session_data[:info][:access_token_hash]
              @user.save
              session[:omniauth][:zenodo] = true
              redirect '/profile/settings'
            end

            delete '/zenodo' do
              protected!
              @user.zenodo_access_token = nil
              @user.zenodo_doi = nil
              @user.zenodo_concept_doi = nil
              @user.save
              { message: "ok" }.to_json
            end

            get '/failure' do
              session.clear
              redirect '/profile'
            end
          end

          app.namespace '/profile' do
            before  { protected! }

            get '' do
              @stats = cache_block("#{@user.identifier}-stats") { user_stats(@user) }
              @families_identified = @user.identified_families
              @families_recorded = @user.recorded_families
              haml :'profile/overview', locals: { active_page: "profile" }
            end

            get '.json' do
              content_type "application/json", charset: 'utf-8'
              @stats = cache_block("#{@user.identifier}-stats") { user_stats(@user) }
              {
                name: @user.fullname,
                orcid: @user.orcid,
                image_url: profile_image(@user, 'medium'),
                stats: @stats
              }.to_json
            end

            post '/image' do
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

            delete '/image' do
              if @user.image_url
                FileUtils.rm(File.join(app.root, "public", "images", "users", @user.image_url)) rescue nil
              end
              @user.image_url = nil
              @user.save
              { message: "ok" }.to_json
            end

            get '/settings' do
              haml :'profile/settings', locals: { active_page: "profile" }
            end

            put '/settings' do
              youtube_id = params[:youtube_id] && !params[:youtube_id].empty? ? params[:youtube_id] : nil
              locale = params[:locale] && !params[:locale].empty? ? params[:locale] : nil
              @user.wants_mail = params[:wants_mail] || false
              @user.youtube_id = youtube_id
              @user.locale = locale
              @user.save
              flash.next[:updated] = true
              canonical_host = request.env['HTTP_HOST'].match(/(?:[a-z]{2}\.)?(.*)$/)
              redirect "#{request.env['rack.url_scheme']}://#{canonical_host[1]}/profile/settings"
            end

            get '/specimens' do
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

            get '/support' do
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

            get '/support/:id' do
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

            get '/helped' do
              @pagy, @results = pagy(@user.latest_helped, items: 15)
              haml :'profile/helped', locals: { active_page: "profile" }
            end

            get '/messages' do
              @user.messages_received.update_all({ read: true })
              @pagy, @results = pagy(@user.latest_messages_by_senders)
              haml :'profile/messages', locals: { active_page: "profile" }
            end

            put '/visibility.json' do
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

            get '/download.json(ld)?' do
              attachment "#{@user.orcid}.json"
              cache_control :public, :must_revalidate, :no_cache, :no_store
              headers.delete("Content-Length")
              content_type "application/ld+json", charset: 'utf-8'
              io = ::Bionomia::IO.new({ user: @user })
              io.jsonld_stream("all")
            end

            get '/download.csv' do
              records = @user.visible_occurrences
              csv_stream_headers(@user.orcid)
              io = ::Bionomia::IO.new
              body io.csv_stream_occurrences(records)
            end

            get '/candidate-count.json' do
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

            get '/message-count.json' do
              content_type "application/json", charset: 'utf-8'
              return { count: 0}.to_json if @user.family.nil?

              count = @user.messages_received.where(read: false).count
              { count: count }.to_json
            end

            get '/candidates.csv' do
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

            get '/candidates' do
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

            post '/advanced-search' do
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

            get '/advanced-search' do
              filter_instances
              haml :'profile/advanced_search', locals: { active_page: "profile" }
            end

            get '/upload' do
              haml :'profile/upload', locals: { active_page: "profile" }
            end

            post '/upload-result' do
              begin
                upload_file(user_id: @user.id, created_by: @user.id)
              rescue => e
                flash.now[:error] = e.message
              end
              haml :'profile/upload_result', locals: { active_page: "profile" }
            end

            get '/ignored' do
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

            get '/citations.csv' do
              csv_stream_headers("citations")
              io = ::Bionomia::IO.new
              body io.csv_stream_articles_profile(@user, @user.articles_citing_specimens)
            end

            get '/citations' do
              page = (params[:page] || 1).to_i
              @pagy, @results = pagy(@user.articles_citing_specimens, items: 10, page: page)
              haml :'profile/citations', locals: { active_page: "profile" }
            end

            get '/citation/*' do
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

            get '/co-collectors' do
              page = (params[:page] || 1).to_i
              @pagy, @results = pagy(@user.recorded_with, page: page)
              haml :'profile/co_collectors', locals: { active_page: "profile", active_tab: "co_collectors" }
            end

            get '/co-collector/:id' do
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

            get '/identified-for' do
              page = (params[:page] || 1).to_i
              @pagy, @results = pagy(@user.identified_for, page: page)
              haml :'profile/identified_for', locals: { active_page: "profile", active_tab: "identified_for" }
            end

            get '/identified-for/:id' do
              @collector = find_user(@params[:id])

              @page = (params[:page] || 1).to_i
              specimens = @user.identifications_for(@collector)
              @total = specimens.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end

              @page = 1 if @page <= 0
              @pagy, @results = pagy(specimens, items: search_size, page: @page)
              haml :'profile/identified_for_specimens', locals: { active_page: "profile", active_tab: "identified_for" }
            end

            get '/identifications-by' do
              page = (params[:page] || 1).to_i
              @pagy, @results = pagy(@user.identified_by, page: page)
              haml :'profile/identifications_by', locals: { active_page: "profile", active_tab: "determiners" }
            end

            get '/identifications-by/:id' do
              @determiner = find_user(@params[:id])

              @page = (params[:page] || 1).to_i
              identifications = @user.identifications_by(@determiner)
              @total = identifications.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end

              @page = 1 if @page <= 0
              @pagy, @results = pagy(identifications, items: search_size, page: @page)
              haml :'profile/identifications_by_specimens', locals: { active_page: "profile", active_tab: "determiners" }
            end

            post '/message.json' do
              content_type "application/json", charset: 'utf-8'
              req = JSON.parse(request.body.read).symbolize_keys
              m = Message.new
              m.user_id = @user.id
              recipient = find_user(req[:recipient_identifier])
              m.recipient_id = recipient.id
              m.save
              { message: "ok", occurrence_id: params[:occurrence_id] }.to_json
            end

            delete '/destroy' do
              @user.destroy
              session.clear
              redirect '/'
            end

            post '/user-occurrence/bulk.json' do
              content_type "application/json", charset: 'utf-8'
              req = JSON.parse(request.body.read).symbolize_keys
              action = req[:action] rescue nil
              visible = req[:visible] rescue true
              occurrence_ids = req[:occurrence_ids].split(",")
              if !visible
                UserOccurrence.where({ occurrence_id: occurrence_ids, user_id: @user[:id] })
                              .destroy_all
              end
              data = occurrence_ids.map{|o| {
                  user_id: @user.id,
                  occurrence_id: o.to_i,
                  created_by: @user.id,
                  action: action,
                  visible: visible
                }
              }
              UserOccurrence.transaction do
                UserOccurrence.import data, batch_size: 250, validate: false, on_duplicate_key_ignore: true
              end
              { message: "ok" }.to_json
            end

            post '/user-occurrence/:occurrence_id.json' do
              content_type "application/json", charset: 'utf-8'
              req = JSON.parse(request.body.read).symbolize_keys
              action = req[:action] rescue nil
              visible = req[:visible] rescue true
              uo = UserOccurrence.new
              uo.user_id = @user.id
              uo.occurrence_id = params[:occurrence_id]
              uo.created_by = @user.id
              uo.action = action
              uo.visible = visible
              begin
                uo.save
              rescue ActiveRecord::RecordNotUnique
              end
              { message: "ok", id: uo.id }.to_json
            end

            put '/user-occurrence/bulk.json' do
              content_type "application/json", charset: 'utf-8'
              req = JSON.parse(request.body.read).symbolize_keys
              action = req[:action] rescue nil
              visible = req[:visible] rescue true
              ids = req[:occurrence_ids].split(",")
              UserOccurrence.where({ id: ids, user_id: @user.id })
                            .update_all({ action: action, visible: visible })
              { message: "ok" }.to_json
            end

            put '/user-occurrence/:id.json' do
              content_type "application/json", charset: 'utf-8'
              req = JSON.parse(request.body.read).symbolize_keys
              uo = UserOccurrence.find_by({ id: params[:id], user_id: @user.id })
              uo.action = req[:action] ||= nil
              uo.visible = req[:visible] ||= true
              uo.save
              { message: "ok" }.to_json
            end

            delete '/user-occurrence/bulk.json' do
              content_type "application/json", charset: 'utf-8'
              req = JSON.parse(request.body.read).symbolize_keys
              ids = req[:ids].split(",")
              UserOccurrence.where({ id: ids, user_id: @user.id })
                            .delete_all
              { message: "ok" }.to_json
            end

            delete '/user-occurrence/:id.json' do
              content_type "application/json", charset: 'utf-8'
              UserOccurrence.where({ id: params[:id], user_id: @user.id })
                            .delete_all
              { message: "ok" }.to_json
            end

          end

        end

      end
    end
  end
end
