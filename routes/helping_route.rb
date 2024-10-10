# encoding: utf-8

module Sinatra
  module Bionomia
    module Route
      module HelpingRoute

        def self.registered(app)

          app.namespace '/help-others' do
            before  { protected! }

            get '' do
              @results = []
              @friends = @user.who_might_know
              if params[:q] && !params[:q].blank?
                search_user
              else
                help_roster
              end
              haml :'help/roster', locals: { active_page: "help" }
            end

            get '/progress' do
              latest_claims("living")
              haml :'help/progress', locals: { active_page: "help", active_tab: "orcid" }
            end

            get '/add' do
              haml_i18n :'add', locals: { active_page: "add" }
            end

            post '/add' do
              flash.next[:identifiers] = params[:identifiers].split("\r\n")[0..24]
              redirect '/help-others/add#progress'
            end

            post '/add-user.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              create_user(req[:identifier]).to_json
            end

            get '/progress/wikidata' do
              latest_claims("deceased")
              haml :'help/progress', locals: { active_page: "help", active_tab: "wikidata" }
            end

            get '/new-people' do
              users = User.where.not(orcid: nil).order(created: :desc).limit(25)
              @pagy, @results = pagy(users, limit: 25)
              haml :'help/new_people', locals: { active_page: "help", active_tab: "orcid" }
            end

            get '/new-people/wikidata' do
              users = User.where.not(wikidata: nil).order(created: :desc).limit(25)
              @pagy, @results = pagy(users, limit: 25)
              haml :'help/new_people', locals: { active_page: "help", active_tab: "wikidata" }
            end

            get '/countries' do
              @countries = I18nData.countries(I18n.locale)
                                   .sort_alphabetical_by(&:last)
                                   .group_by{|a| a[1][0]}
              haml :'help/countries', locals: { active_page: "help" }
            end

            get '/country/:country_code' do
              country_code = params[:country_code]
              @country = I18nData.countries(I18n.locale).slice(country_code).flatten
              if @country.empty?
                halt 404, haml(:oops)
              end
              @results = []
              begin
                users = User.where("country_code LIKE ?", "%#{country_code}%").order(:family)
                @pagy, @results = pagy(users, limit: 30)
                haml :'help/country', locals: { active_page: "help" }
              rescue
                status 404
                haml :oops
              end
            end

            post '/user-occurrence/bulk.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              action = req[:action] rescue nil
              visible = req[:visible] rescue true
              occurrence_ids = req[:occurrence_ids].split(",")
              if !visible
                UserOccurrence.where({ occurrence_id: occurrence_ids, user_id: req[:user_id].to_i })
                              .destroy_all
              end
              data = occurrence_ids.map{|o| {
                  user_id: req[:user_id],
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
              uo.user_id = req[:user_id].to_i
              uo.occurrence_id = params[:occurrence_id].to_i
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
              occurrence_ids = req[:occurrence_ids].split(",")
              visible = req[:visible] rescue true
              UserOccurrence.where({ id: occurrence_ids, user_id: req[:user_id].to_i })
                            .update_all({ action: req[:action], visible: visible, created_by: @user.id })
              { message: "ok" }.to_json
            end

            delete '/user-occurrence/bulk.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              occurrence_ids = req[:occurrence_ids].split(",")
              UserOccurrence.where({ id: occurrence_ids, user_id: req[:user_id].to_i })
                            .delete_all
              { message: "ok" }.to_json
            end

            put '/user-occurrence/:id.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              uo = UserOccurrence.find(params[:id])
              uo.action = req[:action] ||= nil
              uo.visible = req[:visible] ||= true
              uo.created_by = @user.id
              uo.save
              { message: "ok" }.to_json
            end

            delete '/user-occurrence/:id.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              UserOccurrence.where(id: params[:id].to_i, user_id: req[:user_id].to_i)
                            .delete_all
              { message: "ok" }.to_json
            end

            get '/occurrence_item' do
              subq = OccurrenceCount.select(:occurrence_id, :agent_count)
                                    .joins("INNER JOIN (SELECT CEIL(RAND() * (SELECT MAX(id) FROM occurrence_counts)) AS id) AS b")
                                    .where("occurrence_counts.id >= b.id")
                                    .where("occurrence_counts.agent_count > 1")
                                    .limit(1)

              occurrence = UserOccurrence.select(:occurrence_id, 'a.agent_count')
                                         .joins("INNER JOIN (#{subq.to_sql}) a ON a.occurrence_id = user_occurrences.occurrence_id")
                                         .where(action: ['recorded', 'recorded,identified', 'identified,recorded'])
                                         .group(:occurrence_id, 'a.agent_count')
                                         .having("count(user_occurrences.user_id) < a.agent_count")
                                         .limit(1)
                                         .unscope(:order)

              @occurrence = Occurrence.find(occurrence.take.occurrence_id)
              @network = occurrence_network.to_json
              @ignored = user_ignoreds.to_json
              haml :'help/occurrence_item', layout: false
            end

            get '/occurrence' do
              haml :'help/occurrence'
            end

            get '/:id' do
              check_redirect

              occurrence_ids = []
              @page = page
              @sort = params[:sort] || nil
              @order = params[:order] || nil

              @viewed_user = find_user(params[:id])

              if !@viewed_user
                halt 404
              end

              if authorized?
                if @viewed_user == @user
                  redirect "/profile/candidates"
                end

                filter_instances

                if @agent
                  id_scores = [{ id: @agent.id, score: 3 }]
                  occurrence_ids = occurrences_by_score(id_scores, @viewed_user)
                else
                  id_scores = candidate_agents(@viewed_user)
                  occurrence_ids = occurrences_by_score(id_scores, @viewed_user)
                end
                specimen_pager(occurrence_ids.uniq)

              end

              haml :'help/user', locals: { active_page: "help" }
            end

            post '/:id/advanced-search' do
              check_identifier
              check_redirect

              @viewed_user = find_user(params[:id])

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
              elsif params[:agent]
                search_agent({ item_size: 75 })
                @agent_results = format_agents
              end

              if params[:taxon_id] && !params[:taxon_id].blank?
                @taxon = Taxon.find(params[:taxon_id]) rescue nil
              elsif params[:taxon] && !params[:taxon].blank?
                search_taxon
                @taxon_results = format_taxon
              end

              if params[:kingdom] && !params[:kingdom].blank? && Taxon.valid_kingdom?(params[:kingdom])
                @kingdom = params[:kingdom]
              end

              if params[:country_code] && !params[:country_code].blank?
                @country_code = params[:country_code]
              end

              haml :'help/advanced_search', locals: { active_page: "help" }
            end

            get '/:id/advanced-search' do
              check_identifier
              check_redirect
              @viewed_user = find_user(params[:id])
              filter_instances
              haml :'help/advanced_search', locals: { active_page: "help" }
            end

            get '/:id/specimens' do
              check_identifier
              check_redirect

              @viewed_user = find_user(params[:id])

              @page = page
              @order = params[:order] || nil
              @sort = params[:sort] || nil
              @total = specimen_filters(@viewed_user).count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              create_filter

              occurrences = specimen_filters(@viewed_user).includes(:claimant)

              if @order && Occurrence.column_names.include?(@order) && ["asc", "desc"].include?(@sort)
                if @order == "eventDate" || @order == "dateIdentified"
                  occurrences = occurrences.order("occurrences.#{@order}_processed": "#{@sort}")
                end
                occurrences = occurrences.order("occurrences.#{@order}": "#{@sort}")
              else
                occurrences = occurrences.order(created: :desc)
              end

              @pagy, @results = pagy(occurrences, limit: search_size, page: @page)
              haml :'help/specimens', locals: { active_page: "help" }
            end

            get '/:id/support' do
              check_identifier
              check_redirect

              @viewed_user = find_user(params[:id])
              @page = page
              helped_by = @viewed_user.helped_by_counts
              @total = helped_by.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy_array(helped_by, limit: search_size, page: @page)
              haml :'help/support', locals: { active_page: "help" }
            end

            get '/:id/visualizations' do
              check_identifier
              check_redirect

              @viewed_user = find_user(@params[:id])

              @stats = user_stats(@viewed_user)
              haml :'help/visualizations', locals: { active_page: "help" }
            end

            get '/:id/specialties' do
              check_identifier
              check_redirect

              @viewed_user = find_user(@params[:id])
              @families_identified = @viewed_user.identified_families_helped
              @families_recorded = @viewed_user.recorded_families_helped
              haml :'help/specialties', locals: { active_page: "help" }
            end

            get '/:id/strings' do
              check_identifier
              check_redirect

              @viewed_user = find_user(@params[:id])
              @pagy, @results = {}, []
              @page = page
              strings = @viewed_user.collector_strings
              @total = strings.count

              if @page*50 > @total
                bump_page = @total % 50 != 0 ? 1 : 0
                @page = @total/50 + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy_array(strings.to_a, limit: 50, page: @page)
              haml :'help/strings', locals: { active_page: "help" }
            end

            get '/:id/co-collectors' do
              check_identifier
              check_redirect

              @viewed_user = find_user(@params[:id])
              @pagy, @results = pagy(@viewed_user.recorded_with, page: page)
              haml :'help/co_collectors', locals: { active_page: "help" }
            end

            get '/:id/co-collector/:id2' do
              check_identifier
              check_redirect

              @viewed_user = find_user(@params[:id])
              @co_collector = find_user(@params[:id2])

              if @viewed_user == @user
                redirect "/profile/co-collector/#{@co_collector.identifier}", 301
              end

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
              
              co_collections = @viewed_user.recordings_with(@co_collector)
                                           .order("occurrences.#{@order} #{@sort}")
              @total = co_collections.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy(co_collections, limit: search_size, page: @page)
              haml :'help/co_collector_specimens', locals: { active_page: "help" }
            end

            get '/:id/identified-for' do
              check_identifier
              check_redirect

              @viewed_user = find_user(@params[:id])
              @pagy, @results = pagy(@viewed_user.identified_for, page: page)
              haml :'help/identified_for', locals: { active_page: "help" }
            end

            get '/:id/identified-for/:id2' do
              check_identifier
              check_redirect

              @viewed_user = find_user(@params[:id])
              @collector = find_user(@params[:id2])

              if @viewed_user == @user
                redirect "/profile/identified-for/#{@collector.identifier}", 301
              end

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

              specimens = @viewed_user.identifications_for(@collector)
                                      .order("occurrences.#{@order} #{@sort}")
              @total = specimens.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy(specimens, limit: search_size, page: @page)
              haml :'help/identified_for_specimens', locals: { active_page: "help" }
            end

            get '/:id/identifications-by' do
              check_identifier
              check_redirect

              @viewed_user = find_user(@params[:id])
              @pagy, @results = pagy(@viewed_user.identified_by, page: page)
              haml :'help/identifications_by', locals: { active_page: "help" }
            end

            get '/:id/identifications-by/:id2' do
              check_identifier
              check_redirect

              @viewed_user = find_user(@params[:id])
              @determiner = find_user(@params[:id2])

              if @viewed_user == @user
                redirect "/profile/identifications-by/#{@determiner.identifier}", 301
              end

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

              determinations = @viewed_user.identifications_by(@determiner)
                                           .order("occurrences.#{@order} #{@sort}")
              @total = determinations.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy(determinations, limit: search_size, page: @page)
              haml :'help/identifications_by_specimens', locals: { active_page: "help" }
            end

            get '/:id/ignored' do
              check_identifier
              check_redirect

              @viewed_user = find_user(params[:id])

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
                hidden_occurrences = @viewed_user.hidden_occurrences_by_others
                                                 .includes(:claimant)
                                                 .order(created: :desc)
              else
                hidden_occurrences = @viewed_user.hidden_occurrences_by_others
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
              haml :'help/ignored', locals: { active_page: "help" }
            end

            get '/:id/bulk-claim' do
              check_identifier
              check_redirect

              @viewed_user = find_user(params[:id])
              @agent_ids = user_agent_ids_unattributed_count(@viewed_user)
              @unattributed_count = @agent_ids.values.sum
              locals = {
                active_page: "help",
                active_tab: "bulk",
                bulk_error: flash.now[:error],
                bulk_count: flash.now[:bulk_count]
              }
              haml :'help/bulk', locals: locals
            end

            post '/:id/bulk-claim' do
              check_identifier
              check_redirect

              @viewed_user = find_user(params[:id])
              agent = Agent.find(params[:agent_id])
              begin
                result = @viewed_user.bulk_claim(agent: agent, conditions: params[:conditions], ignore: params[:ignore], created_by: @user.id)
                flash.next[:bulk_count] = result[:num_attributed]
              rescue ArgumentError => e
                flash.next[:error] = "#{e.message}"
              end
              redirect "/help-others/#{params[:id]}/bulk-claim"
            end

            get '/:id/upload' do
              check_identifier
              check_redirect
              @viewed_user = find_user(params[:id])
              @unattributed_count = user_unattributed_count(@viewed_user)
              haml :'help/upload', locals: { active_page: "help", active_tab: "upload" }
            end

            get '/:id/candidates.csv' do
              content_type "text/csv", charset: 'utf-8'
              csv_stream_headers
              check_identifier
              @viewed_user = find_user(params[:id])
              if !@viewed_user
                halt 404
              end

              agent_ids = candidate_agents(@viewed_user).pluck(:id)
              records = occurrences_by_agent_ids(agent_ids)
                          .where.not({ occurrence_id: @viewed_user.user_occurrences.select(:occurrence_id) })
                          .limit(Settings.helping_download_limit)
              io = ::Bionomia::IO.new
              body io.csv_stream_candidates(records)
            end

            post '/:id/upload-result' do
              check_identifier
              @viewed_user = find_user(params[:id])
              if !@viewed_user
                halt 404
              end

              begin
                upload_file(user_id: @viewed_user.id, created_by: @user.id)
              rescue => e
                flash.now[:error] = e.message
              end
              haml :'help/upload_result', locals: { active_page: "help", active_tab: "upload" }
            end

            put '/:id/visibility' do
              check_identifier
              @viewed_user = find_user(params[:id])
              if !@viewed_user
                halt 404
              end

              if !@viewed_user.is_public
                @viewed_user.update({ is_public: true, made_public: Time.now })
                @viewed_user.update_profile
                @viewed_user.flush_caches
                flash.next[:public] = true
                redirect "/help-others/#{@viewed_user.identifier}"
              end
            end

            get '/:id/helpers.json' do
              content_type "application/json", charset: 'utf-8'
              check_identifier
              viewed_user = find_user(params[:id])
              if !viewed_user
                halt 404, {}.to_json
              end
              helpers = viewed_user.helped_by - [@user]
              { helpers: helpers }.to_json
            end

          end

        end

      end
    end
  end
end
