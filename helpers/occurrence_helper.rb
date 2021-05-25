# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module OccurrenceHelper

        def gbif_occurrence_url(id)
          lang = (I18n.locale == :en) ? "" : "#{I18n.locale}/"
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
              "@vocab" => "http://schema.org/",
              "identified" => "http://rs.tdwg.org/dwc/iri/identifiedBy",
              "recorded" => "http://rs.tdwg.org/dwc/iri/recordedBy",
              "associatedReferences" => "http://rs.tdwg.org/dwc/terms/associatedReferences",
              "PreservedSpecimen" => "http://rs.tdwg.org/dwc/terms/PreservedSpecimen",
          }.merge(dwc_contexts)
          response["@type"] = "PreservedSpecimen"
          response
        end

        def jsonld_occurrence_recordings(occurrence)
          occurrence.user_recordings.map{|o|
            id_url = o.user.orcid ? "https://orcid.org/#{o.user.orcid}" : "http://www.wikidata.org/entity/#{o.user.wikidata}"
            {
                "@type" => "Person",
                "@id" => "#{Settings.base_url}/#{o.user.identifier}",
                "sameAs" => id_url,
                "givenName" => "#{o.user.given}",
                "familyName" => "#{o.user.family}",
                "name" => "#{o.user.fullname}",
                "alternateName" => o.user.other_names.present? ? o.user.other_names.split("|") : []
              }
          }
        end

        def jsonld_occurrence_identifications(occurrence)
          occurrence.user_identifications.map{|o|
            id_url = o.user.orcid ? "https://orcid.org/#{o.user.orcid}" : "http://www.wikidata.org/entity/#{o.user.wikidata}"
            {
                "@type" => "Person",
                "@id" => "#{Settings.base_url}/#{o.user.identifier}",
                "sameAs" => id_url,
                "givenName" => "#{o.user.given}",
                "familyName" => "#{o.user.family}",
                "name" => "#{o.user.fullname}",
                "alternateName" => o.user.other_names.present? ? o.user.other_names.split("|") : []
              }
          }
        end

        def jsonld_occurrence_references(occurrence)
          occurrence.articles.map{|a| {
                "@type" => "ScholarlyArticle",
                "@id" => "https://doi.org/#{a.doi}",
                "sameAs" => "https://doi.org/#{a.doi}",
                "description" => a.citation
              }
          }
        end

      end
    end
  end
end
