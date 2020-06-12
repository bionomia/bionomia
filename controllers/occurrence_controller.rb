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
              response["@id"] = "https://gbif.org/occurrence/#{occurrence.id}"
              response["sameAs"] = "https://gbif.org/occurrence/#{occurrence.id}"
              occurrence.attributes
                        .reject{|column| ignore_cols.include?(column)}
                        .map{|k,v| response[k] = v }

              response["recorded"] = occurrence.user_recordings.map{|o|
                id_url = o.user.orcid ? "https://orcid.org/#{o.user.orcid}" : "https://www.wikidata.org/wiki/#{o.user.wikidata}"
                {
                    "@type": "Person",
                    "@id": id_url,
                    sameAs: id_url,
                    givenName: "#{o.user.given}",
                    familyName: "#{o.user.family}",
                    alternateName: o.user.other_names.present? ? o.user.other_names.split("|") : []
                  }
              }
              response["identified"] = occurrence.user_identifications.map{|o|
                id_url = o.user.orcid ? "https://orcid.org/#{o.user.orcid}" : "https://www.wikidata.org/wiki/#{o.user.wikidata}"
                {
                    "@type": "Person",
                    "@id": id_url,
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
