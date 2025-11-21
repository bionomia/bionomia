# encoding: utf-8

module Sinatra
  module Bionomia
    module Route
      module ProfileRoute

          def self.registered(app)

          app.get '/logout' do
            session.clear
            redirect '/'
          end

          app.get '/:id/unsubscribe' do
            @viewed_user = find_user(params[:id])
            mail_token = params[:mail_token]
            if @viewed_user && @viewed_user.wants_mail? && mail_token == @viewed_user.mail_token
              @viewed_user.skip_callbacks
              @viewed_user.wants_mail = false
              @viewed_user.mail_last_sent = nil
              @viewed_user.mail_token = nil
              @viewed_user.save
              haml :'profile/unsubscribe'
            else
              halt 401, haml(:oops)
            end
          end

          # /auth is automatically added by OmniAuth
          app.namespace '/auth' do
            get '/orcid/callback' do
              session_data = request.env['omniauth.auth'].deep_symbolize_keys
              orcid = session_data[:uid]
              check_banned(orcid)

              #Placeholder material, will be further updated from the after_create callback in User model
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

              user.update(visited: Time.now)
              session[:omniauth] = OpenStruct.new({ id: user.id })
              if request.env['omniauth.origin']
                redirect request.env['omniauth.origin']
              else
                redirect '/profile'
              end
            end

            get '/zenodo/callback' do
              protected!
              session_data = request.env['omniauth.auth'].deep_symbolize_keys
              @user.zenodo_access_token = session_data[:info][:access_token_hash]
              @user.save
              session[:omniauth][:zenodo] = true
              vars = { id: @user.id, action: "new" }.stringify_keys
              ::Bionomia::ZenodoUserWorker.perform_async(vars)
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
                name: @user.viewname,
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
              @user.wants_mail = params[:wants_mail]
              if params[:wants_mail] && params[:wants_mail] != "false" && @user.mail_token.nil?
                @user.mail_token = SecureRandom.hex(10)
              end
              if params.include?(:wants_mail) && (!params[:wants_mail] || params[:wants_mail] == "false")
                @user.mail_token = nil
              end
              @user.youtube_id = youtube_id
              @user.locale = locale
              @user.save

              if request.content_type == "application/json"
                { message: "ok" }.to_json
              else
                flash.next[:updated] = true
                canonical_host = request.env['HTTP_HOST'].match(/(?:[a-z]{2}\.)?(.*)$/)
                redirect "#{request.env['rack.url_scheme']}://#{canonical_host[1]}/profile/settings"
              end
            end

            get '/specimens' do
              @sort = params[:sort] || "desc"
              @order = params[:order] || "typeStatus"
              @page = page
              create_filter

              @total = @user.visible_occurrences.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              if @order && Occurrence.column_names.include?(@order) && ["asc", "desc"].include?(@sort)
                if @order == "eventDate" || @order == "dateIdentified"
                  @order = "#{@order}_processed"
                end
              else
                @sort = "desc"
                @order = "typeStatus"
              end
              data = specimen_filters(@user).order("occurrences.#{@order} #{@sort}")
              @pagy, @results = pagy(data, limit: search_size, page: @page)
              haml :'profile/specimens', locals: { active_page: "profile" }
            end

            get '/support' do
              helped_by = @user.helped_by_counts
              @total = helped_by.count
              @page = page

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy(:offset, helped_by, limit: search_size, page: @page)
              haml :'profile/support', locals: { active_page: "profile" }
            end

            get '/support/:id' do
              @helped_user = find_user(params[:id])
              @page = page
              @sort = params[:sort] || "desc"
              @order = params[:order] || "created"
              if @order && Occurrence.column_names.include?(@order) && ["asc", "desc"].include?(@sort)
                if @order == "eventDate" || @order == "dateIdentified"
                  @order = "#{@order}_processed"
                end
              else
                @sort = "desc"
                @order = "typeStatus"
              end

              if @order == "created"
                claims_received_by = @user.claims_received_by(@helped_user.id)
                                          .order(created: :desc)
              else
                claims_received_by = @user.claims_received_by(@helped_user.id)
                                          .order("occurrences.#{@order} #{@sort}")
              end
              @total = claims_received_by.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy(claims_received_by, limit: search_size, page: @page)
              haml :'profile/support_table', locals: { active_page: "profile" }
            end

            get '/helped' do
              @pagy, @results = pagy(:offset, @user.latest_helped, count_over: true, limit: 25)
              haml :'profile/helped', locals: { active_page: "profile" }
            end

            get '/messages' do
              @user.messages_received.update_all({ read: true })
              data = @user.latest_messages_by_senders.to_a
              @pagy, @results = pagy(:offset, data, count: data.size)
              haml :'profile/messages', locals: { active_page: "profile" }
            end

            put '/visibility.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              @user.is_public = req[:is_public]
              if req[:is_public]
                @user.made_public = Time.now
              end
              @user.save
              { message: "ok"}.to_json
            end

            get '/download.json(ld)?' do
              attachment "#{@user.orcid}.json"
              cache_control :public, :must_revalidate, :no_cache, :no_store
              headers.delete("Content-Length")
              content_type "application/ld+json", charset: 'utf-8'
              io = ::Bionomia::IO.new({ user: @user })
              io.jsonld_stream("all", StringIO.open("", "w+")).string
            end

            get '/download.csv' do
              records = @user.visible_occurrences.includes(:claimant)
              csv_stream_headers(@user.orcid)
              io = ::Bionomia::IO.new
              body io.csv_stream_occurrences(records)
            end

            get '/attributions.csv' do
              records = @user.claims_given.includes(:occurrence, :user)
              csv_stream_headers("attributions")
              io = ::Bionomia::IO.new
              body io.csv_stream_attributions(records)
            end

            get '/who-might-know.json' do
              content_type "application/json", charset: 'utf-8'
              @user.who_might_know.to_json
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
                          .limit(Settings.helping_download_limit)
              csv_stream_headers("bionomia-candidates")
              io = ::Bionomia::IO.new
              body io.csv_stream_candidates(records)
            end

            get '/candidates' do
              occurrence_ids = []
              @page = page
              @sort = params[:sort] || nil
              @order = params[:order] || nil

              filter_instances

              if @agent
                id_scores = [{ id: @agent.id, score: 3 }]
                occurrence_ids = occurrences_by_score(id_scores, @user)
              else
                id_scores = candidate_agents(@user)
                occurrence_ids = occurrences_by_score(id_scores, @user)
              end

              specimen_pager(occurrence_ids.uniq)

              haml :'profile/candidates', locals: { active_page: "profile" }
            end

            post '/advanced-search' do
              @agent_results = []
              @dataset_results = []
              @taxon_results = []
              @agent, @dataset, @taxon, @kingdom, @country_code = nil

              if params[:datasetKey] && !params[:datasetKey].blank?
                @dataset = Dataset.find_by_uuid(params[:datasetKey]) rescue nil
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

              if params[:country_code] && !params[:country_code].blank?
                @country_code = params[:country_code]
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

            get '/bulk-claim' do
              @agent_ids = user_agent_ids_unattributed_count(@user)
              @unattributed_count = @agent_ids.values.sum
              locals = {
                active_page: "specimens",
                active_tab: "upload",
                active_subtab: "bulk_claim",
                bulk_error: flash.now[:error],
                bulk_count: flash.now[:bulk_count]
              }
              haml :'profile/bulk', locals: locals
            end

            post '/bulk-claim' do
              agent = Agent.find(params[:agent_id])
              begin
                result = @user.bulk_claim(agent: agent, conditions: params[:conditions], ignore: params[:ignore], created_by: @user.id)
                flash.next[:bulk_count] = result[:num_attributed]
              rescue ArgumentError => e
                flash.next[:error] = "#{e.message}"
              end
              redirect "/profile/bulk-claim"
            end

            get '/ignored' do
              @page = page
              @sort = params[:sort] || "desc"
              @order = params[:order] || "created"
              if @order && Occurrence.column_names.include?(@order) && ["asc", "desc"].include?(@sort)
                if @order == "eventDate" || @order == "dateIdentified"
                  @order = "#{@order}_processed"
                end
              else
                @sort = "desc"
                @order = "created"
              end

              if @order == "created"
                hidden_occurrences = @user.hidden_occurrences
                                          .includes(:claimant)
                                          .order(created: :desc)
              else
                hidden_occurrences = @user.hidden_occurrences
                                          .includes(:claimant)
                                          .order("occurrences.#{@order} #{@sort}")
              end
              @total = hidden_occurrences.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy(hidden_occurrences, limit: search_size, page: @page)
              haml :'profile/ignored', locals: { active_page: "profile", active_tab: "ignored" }
            end

            get '/citations.csv' do
              csv_stream_headers("citations")
              io = ::Bionomia::IO.new
              body io.csv_stream_articles_profile(@user, @user.articles_citing_specimens)
            end

            get '/citations' do
              @pagy, @results = pagy(@user.articles_citing_specimens, limit: 10, page: page)
              haml :'profile/citations', locals: { active_page: "profile" }
            end

            get '/citation/*.csv' do
              article_from_param
              csv_stream_headers("citations-#{@article.id}")
              io = ::Bionomia::IO.new
              body io.csv_stream_article_specimen_profile(@user, @user.cited_specimens_by_article(@article.id), @article)
            end

            get '/citation/*' do
              article_from_param

              @page = page
              @sort = params[:sort] || "desc"
              @order = params[:order] || "typeStatus"
              if @order && Occurrence.column_names.include?(@order) && ["asc", "desc"].include?(@sort)
                if @order == "eventDate" || @order == "dateIdentified"
                  @order = "#{@order}_processed"
                end
              else
                @sort = "desc"
                @order = "typeStatus"
              end

              cited_specimens = @user.cited_specimens_by_article(@article.id)
                                     .order("occurrences.#{@order} #{@sort}")
              @total = cited_specimens.count
              if @total == 0
                halt 404
              end

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy(cited_specimens, limit: search_size, page: @page)
              haml :'profile/citation', locals: { active_page: "profile" }
            end

            get '/co-collectors' do
              @pagy, @results = pagy(@user.recorded_with, page: page)
              haml :'profile/co_collectors', locals: { active_page: "profile", active_tab: "co_collectors" }
            end

            get '/co-collector/:id' do
              @co_collector = find_user(@params[:id])

              @page = page
              @sort = params[:sort] || "desc"
              @order = params[:order] || "typeStatus"
              if @order && Occurrence.column_names.include?(@order) && ["asc", "desc"].include?(@sort)
                if @order == "eventDate" || @order == "dateIdentified"
                  @order = "#{@order}_processed"
                end
              else
                @sort = "desc"
                @order = "typeStatus"
              end

              co_collections = @user.recordings_with(@co_collector)
                                    .order("occurrences.#{@order} #{@sort}")
              @total = co_collections.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy(co_collections, limit: search_size, page: @page)
              haml :'profile/co_collector_specimens', locals: { active_page: "profile", active_tab: "co_collectors" }
            end

            get '/identified-for' do
              @pagy, @results = pagy(@user.identified_for, page: page)
              haml :'profile/identified_for', locals: { active_page: "profile", active_tab: "identified_for" }
            end

            get '/identified-for/:id' do
              @collector = find_user(@params[:id])

              @sort = params[:sort] || "desc"
              @order = params[:order] || "typeStatus"
              @page = page

              if @order && Occurrence.column_names.include?(@order) && ["asc", "desc"].include?(@sort)
                if @order == "eventDate" || @order == "dateIdentified"
                  @order = "#{@order}_processed"
                end
              else
                @sort = "desc"
                @order = "typeStatus"
              end

              specimens = @user.identifications_for(@collector)
                               .order("occurrences.#{@order} #{@sort}")
              @total = specimens.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy(specimens, limit: search_size, page: @page)
              haml :'profile/identified_for_specimens', locals: { active_page: "profile", active_tab: "identified_for" }
            end

            get '/identifications-by' do
              @pagy, @results = pagy(@user.identified_by, page: page)
              haml :'profile/identifications_by', locals: { active_page: "profile", active_tab: "determiners" }
            end

            get '/identifications-by/:id' do
              @determiner = find_user(@params[:id])

              @page = page
              @sort = params[:sort] || "desc"
              @order = params[:order] || "typeStatus"
              if @order && Occurrence.column_names.include?(@order) && ["asc", "desc"].include?(@sort)
                if @order == "eventDate" || @order == "dateIdentified"
                  @order = "#{@order}_processed"
                end
              else
                @sort = "desc"
                @order = "typeStatus"
              end

              identifications = @user.identifications_by(@determiner)
                                     .order("occurrences.#{@order} #{@sort}")
              @total = identifications.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy(identifications, limit: search_size, page: @page)
              haml :'profile/identifications_by_specimens', locals: { active_page: "profile", active_tab: "determiners" }
            end

            post '/message.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              m = Message.new
              m.user_id = @user.id
              recipient = find_user(req[:recipient_identifier])
              m.recipient_id = recipient.id
              m.save
              { message: "ok", occurrence_id: params[:occurrence_id] }.to_json
            end

            delete '/destroy' do
              BIONOMIA.cache_clear("blocks/#{@user.identifier}-stats")
              reason = params["reason"].truncate(255)
              DestroyedUser.find_or_create_by({ identifier: @user.identifier, reason: reason })
              @user.destroy
              session.clear
              redirect '/'
            end

            post '/user-occurrence/bulk.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
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
              req = env['rack.request.form_hash'].symbolize_keys
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
              req = env['rack.request.form_hash'].symbolize_keys
              action = req[:action] rescue nil
              visible = req[:visible] rescue true
              ids = req[:occurrence_ids].split(",")
              UserOccurrence.where({ id: ids, user_id: @user.id })
                            .update_all({ action: action, visible: visible })
              { message: "ok" }.to_json
            end

            put '/user-occurrence/:id.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              uo = UserOccurrence.find_by({ id: params[:id], user_id: @user.id })
              uo.action = req[:action] ||= nil
              uo.visible = req[:visible] ||= true
              uo.save
              { message: "ok" }.to_json
            end

            delete '/user-occurrence/bulk.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              occurrence_ids = req[:occurrence_ids].split(",")
              UserOccurrence.where({ id: occurrence_ids, user_id: @user.id })
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
