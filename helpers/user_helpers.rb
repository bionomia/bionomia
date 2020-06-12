# encoding: utf-8

module Sinatra
  module Bionomia
    module UserHelpers

      def search_user
        @results = []
        searched_term = params[:q]
        return if !searched_term.present?

        page = (params[:page] || 1).to_i

        client = Elasticsearch::Client.new url: Settings.elastic.server
        body = build_name_query(searched_term)
        from = (page -1) * 30

        response = client.search index: Settings.elastic.user_index, from: from, size: 30, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total][:value], items: 30, page: page)
        @results = results[:hits]
      end

      def find_user(id)
        if id.is_orcid?
          user = User.find_by_orcid(id)
        elsif id.is_wiki_id?
          user = User.find_by_wikidata(id)
        else
          user = User.find(id)
        end
        halt 404 if user.nil?
        user
      end

      def create_user
        if params[:identifier] && !params[:identifier].empty?
          if params[:identifier].is_orcid?
            new_user = User.find_or_create_by({ orcid: params[:identifier] })
            flash.next[:new_user] = { fullname: new_user.fullname, slug: new_user.orcid }
          elsif params[:identifier].is_wiki_id?
            new_user = User.find_or_create_by({ wikidata: params[:identifier] })
            if !new_user.valid_wikicontent?
              flash.next[:new_user] = { fullname: params[:identifier], slug: nil }
              new_user.delete_search
              new_user.delete
            else
              flash.next[:new_user] = { fullname: new_user.fullname, slug: new_user.wikidata }
            end
          else
            flash.next[:new_user] = { fullname: params[:identifier], slug: nil }
          end
        end
      end

      def user_stats(user)
        counts = user.country_counts
        cited = user.cited_specimens_counts
        helped = user.helped_counts

        identified_count = counts.values.reduce(0) {
          |sum, val| sum + val[:identified]
        }
        recorded_count = counts.values.reduce(0) {
          |sum, val| sum + val[:recorded]
        }
        countries_identified = counts.each_with_object({}) do |code, data|
          if code[0] != "OTHER" && code[1][:identified] > 0
            data[code[0]] = code[1][:identified]
          end
        end
        countries_recorded = counts.each_with_object({}) do |code, data|
          if code[0] != "OTHER" && code[1][:recorded] > 0
            data[code[0]] = code[1][:recorded]
          end
        end

        r = user.recorded_bins
        r.each{|k,v| r[k] = [0,v]}

        i = user.identified_bins
        i.each {|k,v| i[k] = [v,0]}

        activity_dates = r.merge(i) do |k, first_val, second_val|
          [[first_val[0], second_val[0]].max, [first_val[1], second_val[1]].max]
        end

        {
          specimens: {
            identified: identified_count,
            recorded: recorded_count
          },
          attributions: {
            helped: helped.count,
            number: helped.values.reduce(:+)
          },
          countries: {
            identified: countries_identified,
            recorded: countries_recorded
          },
          articles: {
            specimens_cited: cited.map(&:second).reduce(:+),
            number: cited.count
          },
          activity_dates: activity_dates
                .delete_if{|k,v| k > Date.today.year || k <= 1700 || v == [0,0] }
                .sort
                .map{|k,v| v.flatten.unshift(k.to_s) }
        }
      end

      def helping_user_stats(user)
        counts = user.country_counts_helped

        identified_count = counts.values.reduce(0) {
          |sum, val| sum + val[:identified]
        }
        recorded_count = counts.values.reduce(0) {
          |sum, val| sum + val[:recorded]
        }
        countries_identified = counts.each_with_object({}) do |code, data|
          if code[0] != "OTHER" && code[1][:identified] > 0
            data[code[0]] = code[1][:identified]
          end
        end
        countries_recorded = counts.each_with_object({}) do |code, data|
          if code[0] != "OTHER" && code[1][:recorded] > 0
            data[code[0]] = code[1][:recorded]
          end
        end

        r = user.recorded_bins_helped
        r.each{|k,v| r[k] = [0,v]}

        i = user.identified_bins_helped
        i.each {|k,v| i[k] = [v,0]}

        activity_dates = r.merge(i) do |k, first_val, second_val|
          [[first_val[0], second_val[0]].max, [first_val[1], second_val[1]].max]
        end

        {
          specimens: {
            identified: identified_count,
            recorded: recorded_count
          },
          countries: {
            identified: countries_identified,
            recorded: countries_recorded
          },
          activity_dates: activity_dates
                .delete_if{|k,v| k > Date.today.year || k <= 1700 || v == [0,0] }
                .sort
                .map{|k,v| v.flatten.unshift(k.to_s) }
        }
      end

    end
  end
end
