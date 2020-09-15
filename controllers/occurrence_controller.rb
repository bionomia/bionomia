# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module OccurrenceController

        def self.registered(app)

          app.get '/occurrence/:id.json' do
            content_type "application/ld+json", charset: 'utf-8'
            ignore_cols = Occurrence::IGNORED_COLUMNS_OUTPUT
            begin
              occurrence = Occurrence.find(params[:id])
              dwc_contexts = Hash[
                  Occurrence.attribute_names
                            .reject {|column| ignore_cols.include?(column)}
                            .map{|o| ["#{o}", "http://rs.tdwg.org/dwc/terms/#{o}"] if !ignore_cols.include?(o) }
              ]
              response = {}
              response["@context"] = {
                  "@vocab": "http://schema.org/",
                  identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
                  recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
                  associatedReferences: "http://rs.tdwg.org/dwc/terms/associatedReferences",
                  PreservedSpecimen: "http://rs.tdwg.org/dwc/terms/PreservedSpecimen",
              }.merge(dwc_contexts)
              response["@type"] = "PreservedSpecimen"
              response["@id"] = "#{base_url}/#{occurrence.id}"
              response["sameAs"] = "https://gbif.org/occurrence/#{occurrence.id}"
              occurrence.attributes
                        .reject{|column| ignore_cols.include?(column)}
                        .map{|k,v| response[k] = v }

              response["recorded"] = occurrence.user_recordings.map{|o|
                id_url = o.user.orcid ? "https://orcid.org/#{o.user.orcid}" : "http://www.wikidata.org/entity/#{o.user.wikidata}"
                {
                    "@type": "Person",
                    "@id": "#{base_url}/#{o.user.identifier}",
                    sameAs: id_url,
                    givenName: "#{o.user.given}",
                    familyName: "#{o.user.family}",
                    alternateName: o.user.other_names.present? ? o.user.other_names.split("|") : []
                  }
              }
              response["identified"] = occurrence.user_identifications.map{|o|
                id_url = o.user.orcid ? "https://orcid.org/#{o.user.orcid}" : "http://www.wikidata.org/entity/#{o.user.wikidata}"
                {
                    "@type": "Person",
                    "@id": "#{base_url}/#{o.user.identifier}",
                    sameAs: id_url,
                    givenName: "#{o.user.given}",
                    familyName: "#{o.user.family}",
                    alternateName: o.user.other_names.present? ? o.user.other_names.split("|") : []
                  }
              }
              response["associatedReferences"] = occurrence.articles.map{|a| {
                    "@type": "ScholarlyArticle",
                    "@id": "https://doi.org/#{a.doi}",
                    sameAs: "https://doi.org/#{a.doi}",
                    description: a.citation
                  }
              }
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
