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
              identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
              recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
              associatedReferences: "http://rs.tdwg.org/dwc/terms/associatedReferences",
              PreservedSpecimen: "http://rs.tdwg.org/dwc/terms/PreservedSpecimen",
              oa: "http://www.w3.org/ns/oa#",
              annotation: "http://www.w3.org/ns/oa#Annotation"
          }.merge(dwc_contexts)
          response
        end

        def jsonld_occurrence_actions(occurrence, type = "identifications")
          occurrence.send("user_#{type}").map{|o|
            id_url = o.user.orcid ? "https://orcid.org/#{o.user.orcid}" : "http://www.wikidata.org/entity/#{o.user.wikidata}"
            annotation = {}
            if !o.claimant.orcid.nil?
              annotation = {
                "@type": "oa:Annotation",
                "@id": "BionomiaLink#{o.id}",
                "oa:motivation": "identifying",
                "oa:target": {
                  "oa:source": "https://gbif.org/occurrence/#{occurrence.id}",
                  "oa:selector": {
                    "oa:type": "TextQuoteSelector",
                    "oa:exact": type == "identifications" ? "Identified by" : "Recorded by"
                  }
                },
                "oa:creator": {
                  "@type": "Person",
                  "@id": "#{Settings.base_url}/#{o.claimant.orcid}",
                  sameAs: "https://orcid.org/#{o.claimant.orcid}",
                  givenName: "#{o.claimant.given}",
                  familyName: "#{o.claimant.family}",
                  name: "#{o.claimant.fullname}",
                  alternateName: o.claimant.other_names.present? ? o.claimant.other_names.split("|") : []
                },
                "oa:created": o.created.to_time.iso8601,
                "oa:modified": !o.updated.nil? ? o.updated.to_time.iso8601 : nil
              }
            end
            {
                "@type": "Person",
                "@id": "#{Settings.base_url}/#{o.user.identifier}",
                sameAs: id_url,
                givenName: "#{o.user.given}",
                familyName: "#{o.user.family}",
                name: "#{o.user.fullname}",
                alternateName: o.user.other_names.present? ? o.user.other_names.split("|") : [],
                "@reverse": {
                  annotation: [ annotation ]
                }
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
