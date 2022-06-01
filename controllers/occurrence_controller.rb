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
                  sameAs: "#{occurrence.uri}",
                  recorded: jsonld_occurrence_actions(occurrence, "recordings"),
                  identified: jsonld_occurrence_actions(occurrence, "identifications"),
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

          app.namespace '/occurrence' do

            get '/:id.json(ld)?' do
              content_type "application/ld+json", charset: 'utf-8'
              response = jsonld_occurrence_context
              response["@type"] = "PreservedSpecimen"
              begin
                occurrence = Occurrence.find(params[:id])
                response["@id"] = "#{Settings.base_url}/occurrence/#{occurrence.id}"
                response["sameAs"] = "#{occurrence.uri}"
                occurrence.attributes
                          .reject{|column| Occurrence::IGNORED_COLUMNS_OUTPUT.include?(column)}
                          .map{|k,v| response[k] = v }

                response["recorded"] = jsonld_occurrence_actions(occurrence, "recordings")
                response["identified"] = jsonld_occurrence_actions(occurrence, "identifications")
                response["associatedReferences"] = jsonld_occurrence_references(occurrence)
                JSON.pretty_generate(response)
              rescue
                halt 404, {}.to_json
              end
            end

            get '/:id/still_images.json' do
              content_type "application/json", charset: 'utf-8'
              Occurrence.find(params[:id])
                        .images
                        .to_json
            end

            get '/:id' do
              @occurrence = Occurrence.includes(:recorders)
                                      .includes(:determiners)
                                      .find(params[:id]) rescue nil
              if @occurrence.nil?
                halt 404
              end

              @network = is_admin? ? occurrence_network.to_json : [].to_json
              @ignored = is_admin? ? user_ignoreds.to_json : [].to_json
              haml :'occurrence/occurrence'
            end

          end

        end

      end
    end
  end
end
