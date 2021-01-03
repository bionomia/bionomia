# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module OccurrenceController

        def self.registered(app)

          app.get '/occurrence/:id.json' do
            content_type "application/ld+json", charset: 'utf-8'
            response = jsonld_occurrence_context
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
              response.to_json
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
            @occurrence = Occurrence.find(params[:id]) rescue nil
            if @occurrence.nil?
              halt 404
            end
            haml :'occurrence/occurrence'
          end

        end

      end
    end
  end
end
