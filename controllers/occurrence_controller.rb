# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module OccurrenceController

        def self.registered(app)

          app.get '/occurrences/search' do
            if !params[:datasetKey] || params[:datasetKey].empty?
              occurrence_api_404
            end
            if !params[:occurrenceID] || params[:occurrenceID].empty?
              occurrence_api_404
            end

            response = jsonld_occurrence_context
            response["@context"]["opensearch"] = "http://a9.com/-/spec/opensearch/1.1/"

            occurrences = Occurrence.where({ datasetKey: params[:datasetKey], occurrenceID: params[:occurrenceID] }) rescue []
            formatted_occurrences = []
            occurrences.find_each do |occurrence|
              occ = {}
              occurrence.attributes
                        .reject{|column| Occurrence::IGNORED_COLUMNS_OUTPUT.include?(column)}
                        .map{|k,v| occ[k] = v }
              formatted_occurrences << {
                "@type": "DataFeedItem",
                item: {
                  "@type": "PreservedSpecimen",
                  "@id": "#{Settings.base_url}/occurrence/#{occurrence.id}",
                  sameAs: "https://gbif.org/occurrence/#{occurrence.id}",
                  recorded: jsonld_occurrence_recordings(occurrence),
                  identified: jsonld_occurrence_identifications(occurrence),
                  associatedReferences: jsonld_occurrence_references(occurrence)
                }.merge(occ)
              }
            end

            feed_obj = {
              "@type": "DataFeed",
              "opensearch:totalResults": occurrences.count,
              "opensearch:itemsPerPage": 1,
              name: "Bionomia occurrence search results",
              description: "Bionomia occurrence search results expressed as a schema.org JSON-LD DataFeed.",
              license: "https://creativecommons.org/publicdomain/zero/1.0/",
              potentialAction: {
                "@type": "SearchAction",
                target: "#{Settings.base_url}/occurrences/search?datasetKey={datasetKey}&occurrenceID={occurrenceID}"
              },
              dataFeedElement: formatted_occurrences
            }

            if params[:callback]
              content_type "application/x-javascript", charset: 'utf-8'
              params[:callback] + '(' + JSON.pretty_generate(response.merge(feed_obj)) + ');'
            else
              content_type "application/ld+json", charset: 'utf-8'
              JSON.pretty_generate(response.merge(feed_obj))
            end
          end

          app.get '/occurrence/widget_item' do
            admin_protected!
            subq = OccurrenceRecorder.select(:occurrence_id, 'count(agent_id) AS agent_count')
                                     .joins(:occurrence)
                                     .where(occurrences: { datasetKey: "1e61b812-b2ec-43d0-bdbb-8534a761f74c" })
                                     .having("agent_count > 1")
                                     .group(:occurrence_id)
                                     .limit(1000)

            occurrence = UserOccurrence.select(:occurrence_id, 'count(user_id) AS user_count', 'a.agent_count AS agent_count')
                          .joins("INNER JOIN (#{subq.to_sql}) a ON user_occurrences.occurrence_id = a.occurrence_id")
                          .where("action IN ('recorded', 'identified,recorded', 'recorded,identified')")
                          .group(:occurrence_id)
                          .having("user_count <> agent_count")
                          .order("RAND()")
                          .limit(1)
            @occurrence = Occurrence.find(occurrence.first.occurrence_id)
            haml :'occurrence/widget_item', layout: false
          end

          app.get '/occurrence/widget' do
            admin_protected!
            haml :'occurrence/widget'
          end

          app.get '/occurrence/:id.json(ld)?' do
            content_type "application/ld+json", charset: 'utf-8'
            response = jsonld_occurrence_context
            response["@type"] = "PreservedSpecimen"
            begin
              occurrence = Occurrence.find(params[:id])
              response["@id"] = "#{Settings.base_url}/occurrence/#{occurrence.id}"
              response["sameAs"] = "https://gbif.org/occurrence/#{occurrence.id}"
              occurrence.attributes
                        .reject{|column| Occurrence::IGNORED_COLUMNS_OUTPUT.include?(column)}
                        .map{|k,v| response[k] = v }

              response["recorded"] = jsonld_occurrence_recordings(occurrence)
              response["identified"] = jsonld_occurrence_identifications(occurrence)
              response["associatedReferences"] = jsonld_occurrence_references(occurrence)
              JSON.pretty_generate(response)
            rescue
              halt 404, {}.to_json
            end
          end

          app.get '/occurrence/:id/still_images.json' do
            content_type "application/json", charset: 'utf-8'
            begin
              response = RestClient::Request.execute(
                method: :get,
                url: "https://api.gbif.org/v1/occurrence/#{params[:id]}"
              )
              result = JSON.parse(response, :symbolize_names => true)
              api = "https://api.gbif.org/v1/image/unsafe/"
              result[:media].map{|a| { original: api + CGI.escape(a[:identifier]), small: "#{api}fit-in/250x/#{CGI.escape(a[:identifier])}", large: "#{api}fit-in/750x/#{CGI.escape(a[:identifier])}" } if a[:type] == "StillImage"}
                            .compact
                            .to_json
            rescue
              [].to_json
            end
          end

          app.get '/occurrence/:id' do
            @occurrence = Occurrence.includes(:recorders)
                                    .includes(:determiners)
                                    .find(params[:id]) rescue nil
            if @occurrence.nil?
              halt 404
            end

            network = Set.new
            if authorized?
              @occurrence.user_recordings.each do |recordings|
                recordings.user.recorded_with.each do |person|
                  network.add({
                    user_id: person.id,
                    identifier: person.identifier,
                    familyName: person.family,
                    fullname: person.fullname })
                end
              end
            end
            @network = network.to_json

            haml :'occurrence/occurrence'
          end

        end

      end
    end
  end
end
