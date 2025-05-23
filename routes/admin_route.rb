# encoding: utf-8

module Sinatra
  module Bionomia
    module Route
      module AdminRoute

        def self.registered(app)

          app.namespace '/admin' do
            before  { admin_protected! }

            get '' do
              haml :'admin/welcome', locals: { active_page: "administration" }
            end

            get '/articles/check-new.json' do
              content_type "application/json", charset: 'utf-8'
              params = {
                max_size: KeyValue.get("gbif_download_max_size").to_i,
                from: (Date.today - 7).to_s
              }
              tracker = ::Bionomia::GbifTracker.new(params)
              tracker.create_package_records
              { message: "ok" }.to_json
            end

            get '/articles' do
              @pagy, @results = pagy(Article.order(created: :desc), limit: 50)
              haml :'admin/articles', locals: { active_page: "administration" }
            end

            post '/article/add' do
              if !params || !params[:doi].is_doi?
                redirect "/admin/articles"
              end

              doi = params[:doi].dup
              article = Article.find_by_doi(doi)
              if article
                redirect "/admin/article/#{article.id}"
              end

              params = {
                max_size: KeyValue.get("gbif_download_max_size").to_i,
                first_page_only: true
              }
              tracker = ::Bionomia::GbifTracker.new(params)
              tracker.by_doi(doi)
              tracker.create_package_records
              Article.uncached do
                article = Article.find_by_doi(doi)
              end
              if article
                redirect "/admin/article/#{article.id}"
              else
                flash.next[:none_found] = doi
                redirect "/admin/articles"
              end
            end

            get '/article/:id/process.json' do
              content_type "application/json", charset: 'utf-8'
              article = Article.find(params[:id]) rescue nil
              if article
                vars = { id: params[:id] }.stringify_keys
                ::Bionomia::ArticleWorker.perform_async(vars)
                article.process_status = 1
                article.save
                { message: "ok" }.to_json
              else
                { message: "failed" }.to_json
              end
            end

            get '/article/:id' do
              @article = Article.find(params[:id]) rescue nil
              if @article.nil?
                halt 404
              end
              haml :'admin/article', locals: { active_page: "administration" }
            end

            post '/article/:id' do
              @article = Article.find(params[:id]) rescue nil
              if @article.nil?
                halt 404
              end
              @article.update(params.except("authenticity_token"))
              flash.next[:updated] = true
              redirect "/admin/article/#{@article.id}"
            end

            delete '/article/:id' do
              article = Article.find(params[:id]) rescue nil
              if article.nil?
                halt 404
              end
              title = article.citation.dup
              article.destroy
              flash.next[:destroyed] = title
              redirect "/admin/articles"
            end

            get '/datasets' do
              sort = params[:sort] || nil
              order = params[:order] || nil
              datasets
              locals = {
                active_page: "administration",
                sort: sort, order: order
              }
              haml :'admin/datasets', locals: locals
            end

            get '/dataset/frictionless.json' do
              content_type "application/json", charset: 'utf-8'

              vars = { uuid: params[:datasetKey] }.stringify_keys
              ::Bionomia::FrictionlessWorker.perform_async(vars)
              { message: "ok" }.to_json
            end

            get '/dataset/refresh.json' do
              content_type "application/json", charset: 'utf-8'

              dataset = ::Bionomia::GbifDataset.new
              dataset.process_dataset(params[:datasetKey])
              @dataset = Dataset.find_by_uuid(params[:datasetKey])
              @dataset.refresh_search
              { message: "ok" }.to_json
            end

            get '/dataset/:id' do
              @dataset = Dataset.find_by_uuid(params[:id]) rescue nil
              if @dataset.nil?
                halt 404
              end
              haml :'admin/dataset', locals: { active_page: "administration" }
            end

            post '/dataset/:id' do
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

            delete '/dataset/:id' do
              dataset = Dataset.find(params[:id]) rescue nil
              if dataset.nil?
                halt 404
              end
              title = dataset.title.dup
              dataset.destroy
              flash.next[:destroyed] = title
              redirect "/admin/datasets"
            end

            get '/datasets/search' do
              search_dataset
              locals = { active_page: "administration" }
              haml :'admin/datasets_search', locals: locals
            end

            get '/organizations' do
              sort = params[:sort] || nil
              order = params[:order] || nil
              organizations
              locals = {
                active_page: "administration",
                sort: sort, order: order
              }
              haml :'admin/organizations', locals: locals
            end

            get '/organizations/search' do
              search_organization
              locals = { active_page: "administration" }
              haml :'admin/organizations_search', locals: locals
            end

            get '/organizations/duplicates' do
              identifier = params[:identifier] ? params[:identifier] : "grid"
              if identifier && !Organization.attribute_names.include?(identifier)
                halt 404
              end
              organizations_duplicates(attribute: identifier)
              locals = { active_page: "administration" }
              haml :'admin/organizations', locals: locals
            end

            put '/organizations/merge' do
              ids = params.keys.map{|k| k.split("merge-").last if k.match?(/merge/) }.compact
              redirect "/admin/organizations" if ids.empty? || ids.size < 2
              begin
                orgs = Organization.merge(ids)
                flash.next[:success] = "#{orgs.map(&:name).join(", ")} were merged."
              rescue Exception => e
                flash.next[:error] = e.message
              end
              redirect back
            end

            get '/organization/:id/refresh.json' do
              content_type "application/json", charset: 'utf-8'
              organization = Organization.find(params[:id])
              organization.update_wikidata
              { message: "ok" }.to_json
            end

            get '/organization/:id/refresh-metrics.json' do
              content_type "application/json", charset: 'utf-8'
              organization = Organization.find(params[:id])
              organization.flush_metrics
              { message: "ok" }.to_json
            end

            get '/organization/:id/codes.json' do
              content_type "application/json", charset: 'utf-8'
              organization = Organization.find(params[:id])
              organization.update_institution_codes
              { message: "ok" }.to_json
            end

            get '/organization/:id' do
              @organization = Organization.find(params[:id]) rescue nil
              if @organization.nil?
                halt 404
              end
              haml :'admin/organization', locals: { active_page: "administration" }
            end

            post '/organization/:id' do
              @organization = Organization.find(params[:id]) rescue nil
              if @organization.nil?
                halt 404
              end
              name = params[:name].blank? ? nil : params[:name]
              address = params[:address].blank? ? nil : params[:address]
              isni = params[:isni].blank? ? nil : params[:isni]
              ror = params[:ror].blank? ? nil : params[:ror]
              grid = params[:grid].blank? ? nil : params[:grid]
              ringgold = params[:ringgold].blank? ? nil : params[:ringgold]
              wikidata = params[:wikidata].blank? ? nil : params[:wikidata]
              institution_codes = params[:institution_codes].empty? ? nil : params[:institution_codes].split("|").map(&:strip)
              data = {
                name: name,
                address: address,
                isni: isni,
                grid: grid,
                ror: ror,
                ringgold: ringgold,
                wikidata: wikidata,
                institution_codes: institution_codes
              }
              wikidata_lib = ::Bionomia::WikidataSearch.new
              code = wikidata || ror || grid || ringgold
              wiki = wikidata_lib.institution_wikidata(code)
              data.merge!(wiki) if wiki
              @organization.update(data)
              flash.next[:updated] = true
              redirect "/admin/organization/#{params[:id]}"
            end

            delete '/organization/:id' do
              organization = Organization.find(params[:id]) rescue nil
              if organization.nil?
                halt 404
              end
              title = organization.name.dup
              organization.destroy
              flash.next[:destroyed] = title
              redirect "/admin/organizations"
            end

            get '/queries' do
              sort = params[:sort] || nil
              order = params[:order] || nil
              if order && BulkAttributionQuery.column_names.include?(order) && ["asc", "desc"].include?(sort)
                data = BulkAttributionQuery.includes(:user, :created_by)
                                           .order("#{order} #{sort}")
              else
                data = BulkAttributionQuery.includes(:user, :created_by)
                                           .order(created_at: :desc)
              end
              locals = {
                active_page: "administration",
                sort: sort, order: order
              }
              @pagy, @results = pagy(data, limit: 50)
              haml :'admin/queries', locals: locals
            end

            get '/settings' do
              @pagy, @results = pagy(KeyValue.all.order(:k), limit: 10)
              haml :'admin/system_settings', locals: { active_page: "administration" }
            end

            put '/settings' do
              params.except("_method", "authenticity_token").compact.each do |k,v|
                v = nil if v.blank?
                if KeyValue.get(k) != v
                  KeyValue.set(k, v)
                end
              end
              flash.next[:updated] = true
              redirect "/admin/settings"
            end

            delete '/settings' do
              KeyValue.destroy(params[:key])
            end

            post '/settings/add' do
              value = params["value"].blank? ? nil : params["value"].strip
              KeyValue.set(params["key"].strip, value)
              flash.next[:updated] = true
              redirect "/admin/settings"
            end
            
            get '/stats' do
              @health = {}
              indices = ["agent", "article", "dataset", "organization", "user", "taxon"]
              indices.each do |index|
                es = Object.const_get("Bionomia::Elastic#{index.capitalize}").new
                @health[index] = { documents: es.count }.merge es.health
                es.stats
              end

              haml :'admin/stats', locals: { active_page: "administration" }
            end

            get '/taxa' do
              if params[:q] && params[:q].present?
                search_taxon
                @taxon_results = format_taxon
              else
                @pagy, @results = pagy(Taxon.includes(:image).order(family: :asc), limit: 50)
              end
              haml :'admin/taxa', locals: { active_page: "administration" }
            end

            get '/taxon/:taxon' do
              taxon_from_param
              haml :'admin/taxon', locals: { active_page: "administration" }
            end

            get '/taxon/:taxon/process.json' do
              content_type "application/json", charset: 'utf-8'
              taxon_from_param
              phylo = ::Bionomia::Phylopic.new
              phylo.upsert(family: @taxon.family)
              TaxonImage.find_by_family(@taxon.family).to_json
            end

            get '/users' do
              sort = params[:sort] || nil
              order = params[:order] || nil
              admin_roster
              locals = {
                active_page: "administration",
                sort: sort, order: order
              }
              haml :'admin/roster', locals: locals
            end

            get '/users/search' do
              search_user
              haml :'admin/user_search', locals: { active_page: "administration" }
            end

            get '/users/destroyed' do
              sort = params[:sort] || nil
              order = params[:order] || nil
              destroyed_users
              locals = {
                active_page: "administration",
                sort: sort, order: order
              }
              haml :'admin/destroyed', locals: locals
            end

            delete '/users/destroyed/:id' do
              destroyed = DestroyedUser.find(params[:id]) rescue nil
              destroyed.destroy if destroyed
              { message: "ok" }.to_json
            end

            get '/user/:id' do
              check_redirect
              @admin_user = find_user(params[:id])
              @stats = cache_block("#{@admin_user.identifier}-stats") { user_stats(@admin_user) }
              @families_identified = @admin_user.identified_families
              @families_recorded = @admin_user.recorded_families
              haml :'admin/overview', locals: { active_page: "administration" }
            end

            put '/user/:id/deceased' do
              User.merge_users(src_id: params[:id], dest_id: params[:wikidata])
              flash.next[:updated] = true
              redirect "/admin/user/#{params[:wikidata]}/settings"
            end

            put '/user/:id' do
              admin_user = User.find(params[:id])
              if !admin_user.orcid.nil?
                youtube_id = !params[:youtube_id].empty? ? params[:youtube_id] : nil
                admin_user.youtube_id = youtube_id
                admin_user.save
              end
              flash.next[:updated] = true
              redirect "/admin/user/#{admin_user.identifier}/settings"
            end

            delete '/user/:id' do
              @admin_user = User.find(params[:id]) rescue nil
              if @admin_user.nil?
                halt 404
              end
              name = @admin_user.viewname.dup
              BIONOMIA.cache_clear("blocks/#{@admin_user.identifier}-stats")
              reason = params["reason"].truncate(255)
              DestroyedUser.find_or_create_by({ identifier: @admin_user.identifier, reason: reason })
              @admin_user.destroy
              flash.next[:destroyed] = name
              redirect '/admin/users'
            end

            post '/user/:id/image' do
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

            delete '/user/:id/image' do
              @admin_user = find_user(params[:id])
              if @admin_user.image_url
                FileUtils.rm(File.join(app.root, "public", "images", "users", @admin_user.image_url)) rescue nil
              end
              @admin_user.image_url = nil
              @admin_user.save
              @admin_user.flush_caches
              { message: "ok" }.to_json
            end

            get '/user/:id/settings' do
              check_redirect
              @admin_user = find_user(params[:id])
              haml :'admin/settings', locals: { active_page: "administration" }
            end

            get '/user/:id/specimens' do
              check_redirect
              @admin_user = find_user(params[:id])
              create_filter
              @sort = params[:sort] || "desc"
              @order = params[:order] || "typeStatus"

              candidate_agents = candidate_agents(@admin_user)
              @user_agent_ids = candidate_agents.map{|a| a[:id]}

              @page = page
              @total = @admin_user.visible_occurrences.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              if @order && Occurrence.column_names.include?(@order) && ["asc", "desc"].include?(@sort)
                if @order == "eventDate" || @order == "dateIdentified"
                  @order = "#{@order}_processed"
                end
              end
              data = specimen_filters(@admin_user)
                      .includes(:claimant)
                      .order("occurrences.#{@order} #{@sort}")
              @pagy, @results = pagy(data, limit: search_size, page: @page)
              haml :'admin/specimens', locals: { active_page: "administration" }
            end

            get '/user/:id/specimens.json(ld)?' do
              content_type "application/ld+json", charset: 'utf-8'
              admin_user = find_user(params[:id])
              attachment "#{admin_user.identifier}.json"
              cache_control :no_cache
              headers.delete("Content-Length")
              io = ::Bionomia::IO.new({ user: admin_user })
              io.jsonld_stream("all", StringIO.open("", "w+")).string
            end

            get '/user/:id/message-count.json' do
              content_type "application/json", charset: 'utf-8'
              admin_user = find_user(params[:id])
              return { count: 0}.to_json if admin_user.family.nil?

              count = admin_user.messages_received.where(read: false).count
              { count: count }.to_json
            end

            get '/user/:id/specimens.csv' do
              admin_user = find_user(params[:id])
              records = admin_user.visible_occurrences.includes(:claimant)
              csv_stream_headers
              io = ::Bionomia::IO.new
              body io.csv_stream_occurrences(records)
            end

            get '/user/:id/attributions.csv' do
              admin_user = find_user(params[:id])
              records = admin_user.claims_given.includes(:occurrence, :user)
              csv_stream_headers("#{id}-attributions")
              io = ::Bionomia::IO.new
              body io.csv_stream_attributions(records)
            end

            get '/user/:id/support' do
              check_redirect
              @admin_user = find_user(params[:id])

              @page = page
              helped_by = @admin_user.helped_by_counts
              @total = helped_by.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy_array(helped_by, limit: search_size, page: @page)
              haml :'admin/support', locals: { active_page: "administration" }
            end

            get '/user/:id/support/:id2' do
              check_redirect
              @admin_user = find_user(params[:id])
              @helped_user = find_user(params[:id2])

              candidate_agents = candidate_agents(@admin_user)
              @user_agent_ids = candidate_agents.map{|a| a[:id]}

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
                claims_received_by = @amin_user.claims_received_by(@helped_user.id)
                                          .order(created: :desc)
              else
                claims_received_by = @admin_user.claims_received_by(@helped_user.id)
                                          .order("occurrences.#{@order} #{@sort}")
              end
              @total = claims_received_by.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy(claims_received_by, limit: search_size, page: @page)
              haml :'admin/support_table', locals: { active_page: "administration" }
            end

            get '/user/:id/helped' do
              check_redirect
              @admin_user = find_user(params[:id])

              @pagy, @results = pagy_arel(@admin_user.latest_helped, limit: 25)
              haml :'admin/helped', locals: { active_page: "administration" }
            end

            get '/user/:id/messages' do
              check_redirect
              @admin_user = find_user(params[:id])

              @pagy, @results = pagy_array(@admin_user.latest_messages_by_senders.to_a)
              haml :'admin/messages', locals: { active_page: "administration" }
            end

            get '/user/:id/candidates.csv' do
              protected!
              content_type "text/csv", charset: 'utf-8'
              @admin_user = find_user(params[:id])
              agent_ids = candidate_agents(@admin_user).pluck(:id)
              records = occurrences_by_agent_ids(agent_ids)
                          .where
                          .not(occurrence_id: @admin_user.user_occurrences.select(:occurrence_id))
              csv_stream_headers
              io = ::Bionomia::IO.new
              body io.csv_stream_candidates(records)
            end

            get '/user/:id/candidates' do
              check_redirect
              occurrence_ids = []
              @page = page
              @sort = params[:sort] || nil
              @order = params[:order] || nil

              @admin_user = find_user(params[:id])
              candidate_agents = candidate_agents(@admin_user)
              @user_agent_ids = candidate_agents.map{|a| a[:id]}

              filter_instances

              if @agent
                occurrence_ids = occurrences_by_score([{ id: @agent.id, score: 3 }], @admin_user)
              else
                occurrence_ids = occurrences_by_score(candidate_agents, @admin_user)
              end

              specimen_pager(occurrence_ids.uniq)

              bulk_error_message = flash.now[:error] ? flash.now[:error] : ""
              locals = {
                active_page: "administration",
                bulk_error: bulk_error_message
              }
              haml :'admin/candidates', locals: locals
            end

            post '/user/:id/advanced-search' do
              @admin_user = find_user(params[:id])

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

              haml :'admin/advanced_search', locals: { active_page: "administration" }
            end

            get '/user/:id/advanced-search' do
              @admin_user = find_user(params[:id])
              filter_instances
              haml :'admin/advanced_search', locals: { active_page: "administration" }
            end

            post '/user/:id/candidates/agent/:agent_id/bulk-claim' do
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

            get '/user/:id/ignored' do
              check_redirect
              @admin_user = find_user(params[:id])
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
                hidden_occurrences = @admin_user.hidden_occurrences
                                          .includes(:claimant)
                                          .order(created: :desc)
              else
                hidden_occurrences = @admin_user.hidden_occurrences
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
              haml :'admin/ignored', locals: { active_page: "administration" }
            end

            get '/user/:id/citations.csv' do
              check_redirect
              @admin_user = find_user(params[:id])
              params.delete(:id)
              csv_stream_headers("#{@admin_user.identifier}_citations")
              io = ::Bionomia::IO.new
              body io.csv_stream_articles_profile(@admin_user, @admin_user.articles_citing_specimens)
            end

            get '/user/:id/citations' do
              check_redirect
              @admin_user = find_user(params[:id])
              cited = @admin_user.articles_citing_specimens
              @total = cited.count

              @pagy, @results = pagy(cited, page: page)
              haml :'admin/citations', locals: { active_page: "administration" }
            end

            get '/user/:id/citation/:article_id' do
              check_redirect
              @admin_user = find_user(params[:id])
              @article = Article.find(params[:article_id])
              if !@article
                halt 404
              end

              candidate_agents = candidate_agents(@admin_user)
              @user_agent_ids = candidate_agents.map{|a| a[:id]}

              @page = page
              cited_specimens = @admin_user.cited_specimens_by_article(@article.id)
              @total = cited_specimens.count

              if @page*search_size > @total
                bump_page = @total % search_size.to_i != 0 ? 1 : 0
                @page = @total/search_size.to_i + bump_page
              end
              @page = 1 if @page <= 0

              @pagy, @results = pagy(cited_specimens, page: @page, limit: search_size)
              haml :'admin/citation', locals: { active_page: "administration" }
            end

            put '/user/:id/visibility.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              admin_user = find_user(params[:id])
              admin_user.is_public = req[:is_public]
              if req[:is_public]
                admin_user.made_public = Time.now
              end
              admin_user.save
              { message: "ok" }.to_json
            end

            put '/user/:id/zenodo.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              admin_user = find_user(params[:id])
              vars = { id: admin_user.id, action: req[:action] }.stringify_keys
              ::Bionomia::ZenodoUserWorker.perform_async(vars)
              { message: "ok" }.to_json
            end

            post '/user-occurrence/bulk.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
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
              data = { action: req[:action], visible: visible, created_by: @user.id }
              UserOccurrence.where(id: occurrence_ids, user_id: req[:user_id].to_i)
                            .update_all(data)
              { message: "ok" }.to_json
            end

            put '/user-occurrence/:id.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              uo = UserOccurrence.find_by(id: params[:id].to_i, user_id: req[:user_id].to_i)
              uo.action = req[:action]
              uo.visible = true
              uo.created_by = @user.id
              uo.save
              { message: "ok" }.to_json
            end

            delete '/user-occurrence/bulk.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              occurrence_ids = req[:occurrence_ids].split(",")
              UserOccurrence.where(id: occurrence_ids, user_id: req[:user_id].to_i)
                            .delete_all
              { message: "ok" }.to_json
            end

            delete '/user-occurrence/:id.json' do
              content_type "application/json", charset: 'utf-8'
              req = env['rack.request.form_hash'].symbolize_keys
              UserOccurrence.where(id: params[:id].to_i, user_id: req[:user_id].to_i)
                            .delete_all
              { message: "ok" }.to_json
            end

          end

        end

      end
    end
  end
end
