# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module FormatterHelper

        include ActionView::Helpers::NumberHelper

        Date::DATE_FORMATS[:month_and_year] = '%B, %Y'
        Date::DATE_FORMATS[:year] = '%Y'

        def h(text)
          Rack::Utils.escape_html(text)
        end

        def url_for url_fragment, mode=:path_only
          case mode
          when :path_only
            base = request.script_name
          when :full_url
            if (request.scheme == 'http' && request.port == 80 ||
                request.scheme == 'https' && request.port == 443)
              port = ""
            else
              port = ":#{request.port}"
            end
            base = "#{request.scheme}://#{request.host}#{port}#{request.script_name}"
          else
            raise "Unknown script_url mode #{mode}"
          end
          "#{base}#{url_fragment}"
        end

        def link_to link_text, url, mode=:path_only
          if(url_for(url,mode)[0,2] == "!!")
            trimmed_url = url_for(url,mode)[2..-1]
            "<a href=\"#{trimmed_url}\">#{link_text}</a>"
          else
            "<a href=\"#{url_for(url,mode)}\">#{link_text}</a>"
          end
        end

        def checked_tag(user_action, action)
          (user_action == action) ? "checked" : ""
        end

        def active_class(user_action, action)
          (user_action == action) ? "active" : ""
        end

        def radio_checked(user_action, action)
          (user_action == action) ? true : false
        end

        def country_name(code)
          I18nData.countries(I18n.locale)[code] || nil
        end

        def format_frictionless_links(links)
          content = []
          links.sort{|a, b| b[:name] <=> a[:name] }.each do |link|
            content << "<li><a href=\"#{link[:path]}\">#{link[:name].titleize}</a> (csv, zip)</li>"
          end
          content.join
        end

        def format_agents
          @results.map{ |n|
            { id: n[:_source][:id],
              score: n[:_score],
              fullname: n[:_source][:fullname],
              fullname_reverse: n[:_source][:fullname_reverse],
              given: n[:_source][:given],
              family: n[:_source][:family]
            }
          }
        end

        def format_users
          @results.map{ |n|
            lifespan = n[:_source][:wikidata] ? format_lifespan(n[:_source]) : nil
            uri = n[:_source][:wikidata] \
                  ? "http://www.wikidata.org/entity/#{n[:_source][:wikidata]}" \
                  : "https://orcid.org/#{n[:_source][:orcid]}"
            { id: n[:_source][:id],
              score: n[:_score],
              orcid: n[:_source][:orcid],
              wikidata: n[:_source][:wikidata],
              uri: uri,
              fullname: n[:_source][:fullname],
              fullname_reverse: n[:_source][:fullname_reverse],
              given: n[:_source][:given],
              family: n[:_source][:family],
              label: n[:_source][:label],
              other_names: n[:_source][:other_names],
              thumbnail: n[:_source][:thumbnail],
              image: n[:_source][:image],
              lifespan: lifespan,
              description: n[:_source][:description],
              is_public: n[:_source][:is_public],
              has_occurrences: n[:_source][:has_occurrences]
            }
          }
        end

        def format_organizations
          @results.map{ |n|
            { id: n[:_source][:id],
              score: n[:_score],
              name: n[:_source][:name],
              address: n[:_source][:address],
              institution_codes: n[:_source][:institution_codes],
              isni: n[:_source][:isni],
              ringgold: n[:_source][:ringgold],
              grid: n[:_source][:grid],
              wikidata: n[:_source][:wikidata],
              preferred: n[:_source][:preferred]
            }
          }
        end

        def format_datasets
          @results.map{ |n|
            { id: n[:_source][:id],
              score: n[:_score],
              title: n[:_source][:title].truncate(100, separator: ' '),
              datasetkey: n[:_source][:datasetkey],
              top_institution_codes: n[:_source][:top_institution_codes]
            }
          }
        end

        def format_taxon
          @results.map{ |n|
            { id: n[:_source][:id],
              name: n[:_source][:name]
            }
          }
        end

        def format_articles
          @results.map{ |n|
            { id: n[:_source][:id],
              score: n[:_score],
              citation: n[:_source][:citation],
              doi: n[:_source][:doi]
            }
          }
        end

        def format_lifespan(user)
          if user.is_a?(User)
            date_born = user[:date_born]
            date_died = user[:date_died]
          else
            date_born = Date.parse(user[:date_born]) rescue nil
            date_died = Date.parse(user[:date_died]) rescue nil
          end
          if user[:date_born_precision] == "day"
            born = I18n.l date_born, format: :long
          elsif user[:date_born_precision] == "month"
            born = I18n.l date_born, format: :month_and_year
          elsif user[:date_born_precision] == "year"
            born = I18n.l date_born, format: :year
          elsif user[:date_born_precision] == "century"
            born = I18n.l date_born, format: :century
          else
            born = "?"
          end

          if user[:date_died_precision] == "day"
            died = I18n.l date_died, format: :long
          elsif user[:date_died_precision] == "month"
            died = I18n.l date_died, format: :month_and_year
          elsif user[:date_died_precision] == "year"
            died = I18n.l date_died, format: :year
          elsif user[:date_died_precision] == "century"
            died = I18n.l date_died, format: :century
          else
            died = "?"
          end

          [born, died].join(" &ndash; ")
        end

        def sort_icon(field, direction)
          sorted_field = params[:order]
          if field == sorted_field
            if direction == "asc"
              "<i class=\"fas fa-sort-down\"></i>"
            elsif direction == "desc"
              "<i class=\"fas fa-sort-up\"></i>"
            end
          else
            "<i class=\"fas fa-sort\"></i>"
          end
        end

        def format_coordinate(coord)
          sign = 1
          if coord =~ /[ws]/i
            sign = -1
          end
          coord.to_f * sign
        end

        def format_license(license)
          if license == "CC_BY_4_0"
            "<a href=\"https://creativecommons.org/licenses/by/4.0/legalcode\">https://creativecommons.org/licenses/by/4.0/legalcode</a>"
          elsif license == "CC_BY_NC_4_0"
            "<a href=\"https://creativecommons.org/licenses/by-nc/4.0/legalcode\">https://creativecommons.org/licenses/by-nc/4.0/legalcode</a>"
          elsif license == "CC0_1_0"
            "<a href=\"https://creativecommons.org/publicdomain/zero/1.0/legalcode\">https://creativecommons.org/publicdomain/zero/1.0/legalcode</a>"
          else
            license
          end
        end

      end
    end
  end
end
