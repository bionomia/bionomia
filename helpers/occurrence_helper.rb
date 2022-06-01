# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module OccurrenceHelper

        def gbif_occurrence_url(id)
          lang = [:fr, :es, :pt].include?(I18n.locale) ? "#{I18n.locale}/" : ""
          "https://gbif.org/#{lang}occurrence/#{id}"
        end

        def jsonld_occurrence_context
          response = {}
          ignore_cols = Occurrence::IGNORED_COLUMNS_OUTPUT
          dwc_contexts = Hash[
            Occurrence.attribute_names
                      .reject {|column| ignore_cols.include?(column)}
                      .map{|o| ["#{o}", "http://rs.tdwg.org/dwc/terms/#{o}"] if !ignore_cols.include?(o) }
          ]
          response["@context"] = {
            "@vocab": "http://schema.org/",
            sameAs: {
              "@id": "sameAs",
              "@type": "@id"
            },
            identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
            recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
            associatedReferences: "http://rs.tdwg.org/dwc/terms/associatedReferences",
            PreservedSpecimen: "http://rs.tdwg.org/dwc/terms/PreservedSpecimen"
          }.merge(dwc_contexts).merge({
            datasetKey: "http://rs.gbif.org/terms/1.0/datasetKey",
            license: "http://purl.org/dc/terms/license"
           })
          response
        end

        def jsonld_occurrence_actions(occurrence, type = "identifications")
          occurrence.send("user_#{type}").map{|o|
            id_url = o.user.orcid ? "https://orcid.org/#{o.user.orcid}" : "http://www.wikidata.org/entity/#{o.user.wikidata}"
            {
              "@type": "Person",
              "@id": "#{Settings.base_url}/#{o.user.identifier}",
              sameAs: id_url,
              givenName: "#{o.user.given}",
              familyName: "#{o.user.family}",
              name: "#{o.user.fullname}",
              alternateName: o.user.other_names.present? ? o.user.other_names.split("|") : []
            }
          }
        end

        def jsonld_occurrence_references(occurrence)
          occurrence.articles.map{|a| {
              "@type": "ScholarlyArticle",
              "@id": "https://doi.org/#{a.doi}",
              sameAs: "https://doi.org/#{a.doi}",
              description: a.citation
            }
          }
        end

        def occurrence_api_404
          if params[:callback]
            content_type "application/x-javascript", charset: 'utf-8'
            halt 404, params[:callback] + '(' + {}.to_json + ');'
          else
            content_type "application/json", charset: 'utf-8'
            halt 404, {}.to_json
          end
        end

        def occurrence_network
          network = Set.new
          @occurrence.user_recordings.each do |recordings|
            recordings.user.recorded_with.each do |person|
              lifespan = person.wikidata ? format_lifespan(person) : nil
              network.add({
                user_id: person.id,
                identifier: person.identifier,
                fullname: person.fullname,
                fullname_reverse: person.fullname_reverse,
                lifespan: lifespan
              })
            end
          end
          network
        end

        def user_ignoreds
          ignored_users = Set.new
          @occurrence.user_ignoreds.each do |ignored|
            ignored_users.add({
              user_id: ignored.user.id,
              identifier: ignored.user.identifier,
              fullname: ignored.user.fullname,
              fullname_reverse: ignored.user.fullname_reverse
            })
          end
          ignored_users
        end

      end
    end
  end
end
