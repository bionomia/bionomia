# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module HelpingController

        def self.registered(app)

          app.get '/help-others' do
            protected!
            @results = []
            @countries = IsoCountryCodes.for_select
                                        .group_by{|u| ActiveSupport::Inflector.transliterate(u[0][0]) }
            if params[:q]
              search_user
            end
            haml :'help/others', locals: { active_page: "help" }
          end

          app.get '/help-others/:id/candidate-count.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            user = find_user(params[:id])
            return { count: 0 }.to_json if user.family.nil?

            agent_ids = candidate_agents(user).pluck(:id)
            count = occurrences_by_agent_ids(agent_ids)
                      .where.not({ occurrence_id: user.user_occurrences.select(:occurrence_id) })
                      .pluck(:occurrence_id)
                      .uniq
                      .count
            { count: count }.to_json
          end

          app.get '/help-others/:id/refresh.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            user = find_user(params[:id])
            user.update_profile
            user.flush_caches
            { message: "ok" }.to_json
          end

          app.get '/help-others/progress' do
            protected!
            latest_claims("living")
            haml :'help/progress', locals: { active_page: "help", active_tab: "orcid" }
          end

          app.get '/help-others/add' do
            protected!
            haml :'help/add', locals: { active_page: "add" }
          end

          app.post '/help-others/add' do
            protected!
            create_user
            redirect '/help-others/add'
          end

          app.get '/help-others/progress/wikidata' do
            protected!
            latest_claims("deceased")
            haml :'help/progress', locals: { active_page: "help", active_tab: "wikidata" }
          end

          app.get '/help-others/new-people' do
            protected!
            @pagy, @results = pagy(User.where.not(orcid: nil).order(created: :desc), items: 20)
            haml :'help/new_people', locals: { active_page: "help", active_tab: "orcid" }
          end

          app.get '/help-others/new-people/wikidata' do
            protected!
            @pagy, @results = pagy(User.where.not(wikidata: nil).order(created: :desc), items: 20)
            haml :'help/new_people', locals: { active_page: "help", active_tab: "wikidata" }
          end

          app.get '/help-others/country/:country_code' do
            protected!
            country_code = params[:country_code]
            @results = []
            begin
              @country = IsoCountryCodes.find(country_code)
              @pagy, @results = pagy(User.where("country_code LIKE ?", "%#{country_code}%").order(:family), items: 30)
              haml :'help/country', locals: { active_page: "help" }
            rescue
              status 404
              haml :oops
            end
          end

          app.post '/help-others/user-occurrence/bulk.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
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
            UserOccurrence.import data, batch_size: 250, validate: false, on_duplicate_key_ignore: true
            { message: "ok" }.to_json
          end

          app.post '/help-others/user-occurrence/:occurrence_id.json' do
            protected!
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

          app.put '/help-others/user-occurrence/bulk.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            occurrence_ids = req[:occurrence_ids].split(",")
            visible = req[:visible] rescue true
            UserOccurrence.where({ id: occurrence_ids, user_id: req[:user_id].to_i })
                          .update_all({ action: req[:action], visible: visible, created_by: @user.id })
            { message: "ok" }.to_json
          end

          app.delete '/help-others/user-occurrence/bulk.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            occurrence_ids = req[:occurrence_ids].split(",")
            UserOccurrence.where({ id: occurrence_ids, user_id: req[:user_id].to_i })
                          .delete_all
            { message: "ok" }.to_json
          end

          app.put '/help-others/user-occurrence/:id.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            uo = UserOccurrence.find(params[:id])
            uo.action = req[:action] ||= nil
            uo.visible = req[:visible] ||= true
            uo.created_by = @user.id
            uo.save
            { message: "ok" }.to_json
          end

          app.delete '/help-others/user-occurrence/:id.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            UserOccurrence.where(id: params[:id].to_i, user_id: req[:user_id].to_i)
                          .delete_all
            { message: "ok" }.to_json
          end

          app.get '/help-others/:id' do
            check_identifier
            check_redirect

            occurrence_ids = []
            @page = (params[:page] || 1).to_i

            @viewed_user = find_user(params[:id])

            if !@viewed_user
              halt 404
            end

            if authorized?
              if @viewed_user == @user
                redirect "/profile/candidates"
              end

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

              if @viewed_user.family.nil?
                results = []
                @total = 0
                @pagy, @results = pagy_array(results)
              else
                if @agent
                  id_scores = [{ id: @agent.id, score: 3 }]

                  node = AgentNode.find_by(agent_id: @agent.id)
                  if !node.nil?
                    id_scores.concat(node.agent_nodes_weights.map{|a| { id: a[0], score: a[1] }})
                  end
                else
                  id_scores = candidate_agents(@viewed_user)
                end
                if !id_scores.empty?
                  ids = id_scores.map{|a| a[:id]}
                  nodes = AgentNode.where({ agent_id: ids })
                  if !nodes.empty?
                    (nodes.map(&:agent_id) - ids).each do |id|
                      id_scores << { id: id, score: 1 } #TODO: how to more effectively use the edge weights here?
                    end
                  end
                  occurrence_ids = occurrences_by_score(id_scores, @viewed_user)
                end
                specimen_pager(occurrence_ids.uniq)
              end
            end

            haml :'help/user', locals: { active_page: "help" }
          end

          app.post '/help-others/:id/advanced-search' do
            protected!
            check_identifier
            check_redirect

            @viewed_user = find_user(params[:id])

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

            haml :'help/advanced_search', locals: { active_page: "help" }
          end

          app.get '/help-others/:id/advanced-search' do
            protected!
            check_identifier
            check_redirect

            @viewed_user = find_user(params[:id])
            if params[:datasetKey]
              @dataset = Dataset.find_by_datasetKey(params[:datasetKey]).title rescue nil
            end
            if params[:agent_id]
              @agent = Agent.find(params[:agent_id]).fullname_reverse rescue nil
            end
            if params[:taxon_id]
              @taxon = Taxon.find(params[:taxon_id]).family rescue nil
            end
            haml :'help/advanced_search', locals: { active_page: "help" }
          end

          app.get '/help-others/:id/specimens' do
            protected!
            check_identifier
            check_redirect

            @viewed_user = find_user(params[:id])

            @page = (params[:page] || 1).to_i
            @total = helping_specimen_filters.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            range = nil
            if params[:start_year] || params[:end_year]
              range = [params[:start_year], params[:end_year]].join(" – ")
            end
            country = IsoCountryCodes.find(params[:country_code]).name rescue nil
            family = params[:family] rescue nil
            @filter = {
              action: params[:action],
              country: country,
              range: range,
              family: family
            }.compact

            @pagy, @results = pagy(helping_specimen_filters, items: search_size, page: @page)
            haml :'help/specimens', locals: { active_page: "help" }
          end

          app.get '/help-others/:id/visualizations' do
            protected!
            check_identifier
            check_redirect

            @viewed_user = find_user(@params[:id])
            @stats = helping_user_stats(@viewed_user)
            haml :'help/visualizations', locals: { active_page: "help" }
          end

          app.get '/help-others/:id/specialties' do
            protected!
            check_identifier
            check_redirect

            @viewed_user = find_user(@params[:id])
            @families_identified = @viewed_user.identified_families_helped
            @families_recorded = @viewed_user.recorded_families_helped
            haml :'help/specialties', locals: { active_page: "help" }
          end

          app.get '/help-others/:id/co-collectors' do
            protected!
            check_identifier
            check_redirect

            @viewed_user = find_user(@params[:id])
            begin
              page = (params[:page] || 1).to_i
              @pagy, @results = pagy(@viewed_user.recorded_with, page: page)
              haml :'help/co_collectors', locals: { active_page: "help" }
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/help-others/:id/co-collector/:id2' do
            protected!
            check_identifier
            check_redirect

            @viewed_user = find_user(@params[:id])
            @co_collector = find_user(@params[:id2])

            @page = (params[:page] || 1).to_i
            co_collections = @viewed_user.recordings_with(@co_collector)
            @total = co_collections.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0
            @pagy, @results = pagy(co_collections, items: search_size, page: @page)
            haml :'help/co_collector_specimens', locals: { active_page: "help" }
          end

          app.get '/help-others/:id/ignored' do
            protected!
            check_identifier
            check_redirect

            @viewed_user = find_user(params[:id])

            @page = (params[:page] || 1).to_i
            @total = @viewed_user.hidden_occurrences_by_others.count

            if @page*search_size > @total
              bump_page = @total % search_size.to_i != 0 ? 1 : 0
              @page = @total/search_size.to_i + bump_page
            end

            @page = 1 if @page <= 0

            @pagy, @results = pagy(@viewed_user.hidden_occurrences_by_others, items: search_size, page: @page)
            haml :'help/ignored', locals: { active_page: "help" }
          end

          app.get '/help-others/:id/upload' do
            protected!
            check_identifier
            check_redirect

            @viewed_user = find_user(params[:id])
            haml :'help/upload', locals: { active_page: "help" }
          end

          app.get '/help-others/:id/candidates.csv' do
            protected!
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

          app.post '/help-others/:id/upload-result' do
            protected!
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
            haml :'help/upload_result', locals: { active_page: "help" }
          end

          app.put '/help-others/:id/visibility' do
            protected!
            check_identifier
            @viewed_user = find_user(params[:id])
            if !@viewed_user
              halt 404
            end

            if !@viewed_user.is_public
              @viewed_user.update({ is_public: true, made_public: Time.now })
              @viewed_user.update_profile
              @viewed_user.flush_caches
              if !Settings.twitter.consumer_key.blank?
                vars = { user_id: @viewed_user.id }
                ::Bionomia::TwitterWorker.perform_async(vars)
              end
              flash.next[:public] = true
              redirect "/help-others/#{@viewed_user.identifier}"
            end
          end

          app.get '/help-others/:id/helpers.json' do
            protected!
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
