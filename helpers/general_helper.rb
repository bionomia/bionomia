# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module GeneralHelper

        def haml_i18n(template, *args)
          if File.exists? "views/#{template}.#{I18n.locale.to_s}.haml"
            haml("#{template}.#{I18n.locale}".to_sym, *args)
          else
            haml(template, *args)
          end
        end

        def base_url
          @base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
        end

        def locale
          locales = {
            en: "en_US",
            fr: "fr_FR",
            es: "es_ES",
            pt: "pt_PT"
          }
          locales[I18n.locale] || "en_US"
        end

        def check_identifier
          if !params[:id].is_orcid? && !params[:id].is_wiki_id?
            halt 404
          end
        end

        def check_redirect
          destroyed_user = DestroyedUser.where("identifier = ?", params[:id])
                                        .where.not(redirect_to: nil)
          if !destroyed_user.empty?
            dest = request.path.sub(params[:id], destroyed_user.first.redirect_to)
            redirect "#{dest}", 301
          end
        end

        def check_user_public
          if !@viewed_user && !@viewed_user.is_public?
            halt 404
          end
        end

        def clear_caches(user)
          cache_clear "blocks/#{user.identifier}-stats"
          cache_clear "blocks/#{user.identifier}-scribe"
        end

        def latest_claims(type = "living")
          user_type = (type == "living") ? { orcid: nil } : { wikidata: nil }
          subq = UserOccurrence.select("user_occurrences.user_id AS user_id, MAX(user_occurrences.created) AS created")
                                .group("user_occurrences.user_id")

          qry = UserOccurrence.select(:user_id, :created_by, :created)
                              .joins(:user)
                              .joins("INNER JOIN (#{subq.to_sql}) sub ON sub.user_id = user_occurrences.user_id AND sub.created = user_occurrences.created")
                              .preload(:user, :claimant)
                              .where("user_occurrences.user_id != user_occurrences.created_by")
                              .where.not(created_by: User::BOT_IDS)
                              .where.not(users: user_type)
                              .order(created: :desc)
                              .distinct

          @pagy, @results = pagy_arel(qry, items: 20)
        end

        def example_profiles
          @results = User.where(is_public: true).limit(6).order(Arel.sql("RAND()"))
        end

        def occurrences_by_score(id_scores, user)
          scores = {}
          id_scores.sort{|a,b| b[:score] <=> a[:score]}
                   .each{|a| scores[a[:id]] = a[:score] }

          occurrences = occurrences_by_agent_ids(scores.keys)
                          .where.not(occurrence_id: user.user_occurrences.select(:occurrence_id))

          if @dataset && @dataset[:datasetKey]
            occurrences = occurrences.where(occurrences: { datasetKey: @dataset[:datasetKey] })
          end

          if @taxon && @taxon[:family]
            occurrences = occurrences.where(occurrences: { family: @taxon[:family] })
          end

          occurrences.pluck(:agent_id, :typeStatus, :occurrence_id)
                     .sort_by{|o| [ scores.fetch(o[0]), o[1].nil? ? "" : o[1] ] }
                     .reverse
                     .map(&:last)
        end

        def occurrences_by_agent_ids(agent_ids = [])
          OccurrenceRecorder.where({ agent_id: agent_ids })
                            .union_all(OccurrenceDeterminer.where(agent_id: agent_ids))
                            .includes(:occurrence)
        end

        def search_size
          if [25,50,100,250].include?(params[:per].to_i)
            params[:per].to_i
          else
            25
          end
        end

        def specimen_pager(occurrence_ids)
          @total = occurrence_ids.length
          if @page*search_size > @total && @total > search_size
            @page = @total % search_size == 0 ? @total/search_size : (@total/search_size).to_i + 1
          end
          if @total < search_size || @total == search_size
            @page = 1
          end
          @pagy, results = pagy_array(occurrence_ids, items: search_size, page: @page)
          @results = Occurrence.find(occurrence_ids[@pagy.offset, search_size])
          if @total > 0 && @results.empty?
            @page -= 1
            @pagy, results = pagy_array(occurrence_ids, items: search_size, page: @page)
            @results = Occurrence.find(occurrence_ids[@pagy.offset, search_size])
          end
        end

        def specimen_filters(user)
          if params[:action] && !["collected","identified"].include?(params[:action])
            halt 404, haml(:oops)
          elsif params[:action] && ["collected","identified"].include?(params[:action])
            if params[:action] == "collected"
              results = user.recordings
              if params[:start_year]
                start_date = Date.new(params[:start_year].to_i)
                if start_date > Date.today
                  halt 404, haml(:oops)
                end
                results = results.where("occurrences.eventDate_processed >= ?", start_date)
              end
              if params[:end_year]
                end_date = Date.new(params[:end_year].to_i)
                if end_date > Date.today
                  halt 404, haml(:oops)
                end
                results = results.where("occurrences.eventDate_processed <= ?", end_date)
              end
            end
            if params[:action] == "identified"
              results = user.identifications
              if params[:start_year]
                start_date = Date.new(params[:start_year].to_i)
                if start_date > Date.today
                  halt 404, haml(:oops)
                end
                results = results.where("occurrences.dateIdentified_processed >= ?", start_date)
              end
              if params[:end_year]
                end_date = Date.new(params[:end_year].to_i)
                if end_date > Date.today
                  halt 404, haml(:oops)
                end
                results = results.where("occurrences.dateIdentified_processed <= ?", end_date)
              end
            end
          else
            results = user.visible_occurrences
          end

          if params[:country_code] && !params[:country_code].blank?
            country = I18nData.countries(I18n.locale)[params[:country_code]] rescue nil
            if country.nil?
              halt 404
            end
            results = results.where(occurrences: { countryCode: params[:country_code] })
          end

          if params[:family] && !params[:family].blank?
            results = results.where(occurrences: { family: params[:family] })
          end

          if params[:institutionCode] && !params[:institutionCode].blank?
            results = results.where(occurrences: { institutionCode: params[:institutionCode] })
          end

          results
        end

        def helping_specimen_filters
          if params[:action] && !["collected","identified"].include?(params[:action])
            halt 404, haml(:oops)
          elsif params[:action] && ["collected","identified"].include?(params[:action])
            results = @viewed_user.claims_received.joins(:occurrence)
            if params[:action] == "collected"
              results = results.where(@viewed_user.qry_recorded)
              if params[:start_year]
                start_date = Date.new(params[:start_year].to_i)
                if start_date > Date.today
                  halt 404, haml(:oops)
                end
                results = results.where("occurrences.eventDate_processed >= ?", start_date)
              end
              if params[:end_year]
                end_date = Date.new(params[:end_year].to_i)
                if end_date > Date.today
                  halt 404, haml(:oops)
                end
                results = results.where("occurrences.eventDate_processed <= ?", end_date)
              end
            end
            if params[:action] == "identified"
              results = results.where(@viewed_user.qry_identified)
              if params[:start_year]
                start_date = Date.new(params[:start_year].to_i)
                if start_date > Date.today
                  halt 404, haml(:oops)
                end
                results = results.where("occurrences.dateIdentified_processed >= ?", start_date)
              end
              if params[:end_year]
                end_date = Date.new(params[:end_year].to_i)
                if end_date > Date.today
                  halt 404, haml(:oops)
                end
                results = results.where("occurrences.dateIdentified_processed <= ?", end_date)
              end
            end
          else
            results = @viewed_user.claims_received.joins(:occurrence)
          end

          if params[:country_code] && !params[:country_code].blank?
            country = I18nData.countries(I18n.locale)[params[:country_code]] rescue nil
            if country.nil?
              halt 404
            end
            results = results.where(occurrences: { countryCode: params[:country_code] })
          end

          if params[:family] && !params[:family].blank?
            results = results.where(occurrences: { family: params[:family] })
          end

          if params[:attributor] && !params[:attributor].blank?
            attributor = find_user(params[:attributor])
            results = results.where(created_by: attributor.id)
          end

          results
        end

        def roster
          @pagy, @results = pagy(User.where(is_public: true).order(:family))
        end

        def admin_roster
          data = User.order(visited: :desc, family: :asc)
          if params[:order] && User.column_names.include?(params[:order]) && ["asc", "desc"].include?(params[:sort])
            data = User.order("#{params[:order]} #{params[:sort]}")
          end
          @pagy, @results = pagy(data, items: 100)
        end

        def scribes
          results = UserOccurrence.where.not({ created_by: User::BOT_IDS })
                                  .where("user_occurrences.user_id != user_occurrences.created_by")
                                  .group([:user_id, :created_by])
                                  .pluck(:created_by)
                                  .uniq
                                  .map{|u| User.find(u)}
                                  .sort_by{|u| u.family}
          @pagy, @results  = pagy_array(results, items: 30)
        end

      end
    end
  end
end
