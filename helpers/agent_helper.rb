# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module AgentHelper

        def search_agent(opts = { item_size: 25 })
          @results = []
          searched_term = params[:q] || params[:agent]
          return if !searched_term.present?

          page = (params[:page] || 1).to_i

          size = opts[:item_size] || search_size
          client = Elasticsearch::Client.new(
            url: Settings.elastic.server,
            request_timeout: 5*60,
            retry_on_failure: true,
            reload_on_failure: true,
            reload_connections: 1_000,
            adapter: :typhoeus
          )
          body = build_name_query(searched_term)
          from = (page -1) * size

          response = client.search index: Settings.elastic.agent_index, from: from, size: size, body: body
          results = response["hits"].deep_symbolize_keys

          @pagy = Pagy.new(count: results[:total][:value], limit: size, page: page)
          @results = results[:hits]
        end

        def search_agents(search)
          return [] if !search.present?
          client = Elasticsearch::Client.new(
            url: Settings.elastic.server,
            request_timeout: 5*60,
            retry_on_failure: true,
            reload_on_failure: true,
            reload_connections: 1_000,
            adapter: :typhoeus
          )
          body = build_candidate_agent_query(search)
          response = client.search index: Settings.elastic.agent_index, size: 50, body: body
          results = response["hits"].deep_symbolize_keys
          results[:hits].map{|n| n[:_source].merge(score: n[:_score]) }.compact rescue []
        end

        def candidate_agents(user)
          return [] if user.viewname && user.viewname.is_orcid?

          cutoff_score = 65

          agents = search_agents(user.viewname)
          full_names = [user.viewname.dup]
          family_names = [user.family.dup]
          given_names = [user.given.dup]

          full_names << user.family.dup
          agents.concat search_agents(user.family.dup)

          initials = user.initials
          if initials != user.given
            initials.split(".").each_with_index do |element, index|
              abbreviated_name = [initials[0..index*2+1], user.family].join(" ")
              agents.concat search_agents(abbreviated_name)
              full_names << abbreviated_name
              given_names << initials[0..index*2+1].dup
            end
          end

          if !user.other_names.empty?
            user.other_names.split("|").first(10).each do |other_name|
              #Attempt to ignore botanist abbreviation or naked family name, often as "other" name in wikidata
              next if user.family && user.family.include?(other_name.gsub(".",""))

              full_names << other_name
              agents.concat search_agents(other_name)

              #Attempt to tack on family name because single given name often in ORCID
              if !other_name.include?(" ")
                other_name = [other_name, user.family].join(" ")
              end

              full_names << other_name
              agents.concat search_agents(other_name)

              parsed_other_name = Namae.parse(other_name)[0] rescue nil

              if !parsed_other_name.nil? && !parsed_other_name.given.nil?
                abbreviated_name = [parsed_other_name.initials[0..-3], parsed_other_name.family].join(" ")
                full_names << abbreviated_name
                family_names << parsed_other_name.family
                agents.concat search_agents(abbreviated_name)
                given = parsed_other_name.given
                given_names << given
                given_names << given.gsub(/([[:upper:]])[[:lower:]]+/, '\1.')
                                    .gsub(/\s+/, '')
              end
            end
          end

          full_names.uniq!
          family_names.uniq!
          given_names = given_names.compact
          given_names.sort_by!(&:length).reverse!.uniq!

          if !params.has_key?(:relaxed) || params[:relaxed] == "0"
            remove_agents = []

            agents.each do |a|
              # Boost the matches to a family-only name
              if full_names.compact.map{|n| n.transliterate.downcase}.include?(a[:fullname].transliterate.downcase)
                a[:score] += cutoff_score
              else
                # Add to list of agent names to remove if the given names are not similar
                scores = given_names.map{ |g| DwcAgent.similarity_score(g.transliterate.downcase, a[:given].transliterate.downcase) }
                remove_agents << a[:id] if scores.include?(0)

                # Add to list of agent names to remove if the family names are not in the known list
                remove_agents << a[:id] if !family_names.compact.map{|n| n.transliterate.downcase}.include?(a[:family].transliterate.downcase)
              end
            end

            # Flush an agent from the remove list if the score was actually doubly elevated
            agents.each do |a|
              if a[:score] > 2*cutoff_score
                remove_agents.delete(a[:id])
              end
            end

            agents.delete_if{|a| remove_agents.include?(a[:id]) || a[:score] < cutoff_score }
          end

          # Remove agent if score is half the cut-off
          agents.delete_if{|a| a[:score] < 0.5*cutoff_score}

          agents.sort_by{|a| -a[:score]}
        end

        def agent_examples
          client = Elasticsearch::Client.new(
            url: Settings.elastic.server,
            request_timeout: 5*60,
            retry_on_failure: true,
            reload_on_failure: true,
            reload_connections: 1_000,
            adapter: :typhoeus
          )
          body = {
            query: {
              function_score: {
                query: {
                  bool: {
                    must_not: [
                      { term: { family: { value: "" } } }
                    ]
                  },
                },
                functions: [
                  {
                    random_score: {
                      seed: "#{Time.now.to_i}"
                    },
                  }
                ],
                boost_mode: "replace"
              }
            }
          }
          response = client.search index: Settings.elastic.agent_index, size: 50, body: body
          results = response["hits"].deep_symbolize_keys
          results[:hits]
        end

        def agent_filter
          dataset_name = nil
          if params[:datasetKey] && !params[:datasetKey].blank?
            begin
              dataset_name = Dataset.find_by_uuid(params[:datasetKey]).title
            rescue
              halt 404
            end
          end

          taxon_name = nil
          if params[:taxon] && !params[:taxon].blank?
            begin
              taxon_name = Taxon.find_by_family(params[:taxon]).family
            rescue
              halt 404
            end
          end

          @filter = {
            dataset: dataset_name,
            taxon: taxon_name
          }.compact
        end

      end
    end
  end
end
