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
          IsoCountryCodes.find(code).name rescue nil
        end

        def profile_image(user, size=nil)
          img = Settings.base_url + "/images/photo.png"
          cloud_img = "https://abekpgaoen.cloudimg.io/height/200/x/"
          if size == "thumbnail"
            cloud_img = "https://abekpgaoen.cloudimg.io/crop/24x24/n/"
          elsif size == "thumbnail_grey"
            cloud_img = "https://abekpgaoen.cloudimg.io/crop/24x24/fgrey/"
          elsif size == "medium"
            cloud_img = "https://abekpgaoen.cloudimg.io/crop/48x48/n/"
          elsif size == "social"
            cloud_img = "https://abekpgaoen.cloudimg.io/crop/240x240/n/"
          end
          if user.image_url
            if user.wikidata
              img =  cloud_img + user.image_url
            else
              img = cloud_img + Settings.base_url + "/images/users/" + user.image_url
            end
          end
          img
        end

        def organization_image(organization, size=nil)
          img = nil
          cloud_img = "https://abekpgaoen.cloudimg.io/height/200/x/"
          if size == "thumbnail"
            cloud_img = "https://abekpgaoen.cloudimg.io/crop/24x24/n/"
          elsif size == "medium"
            cloud_img = "https://abekpgaoen.cloudimg.io/crop/48x48/n/"
          elsif size == "social"
            cloud_img = "https://abekpgaoen.cloudimg.io/crop/240x240/n/"
          end
          if organization.image_url
            img = cloud_img + organization.image_url
          end
          img
        end

        def signature_image(user)
          img = Settings.base_url + "/images/signature.png"
          cloud_img = "https://abekpgaoen.cloudimg.io/height/80/x/"
          if user.signature_url
            img =  cloud_img + user.signature_url
          end
          img
        end

        def format_agent(n)
          { id: n[:_source][:id],
            score: n[:_score],
            name: [n[:_source][:family].presence, n[:_source][:given].presence].compact.join(", ")
          }
        end

        def format_agents
          @results.map{ |n|
            { id: n[:_source][:id],
              score: n[:_score],
              fullname: n[:_source][:fullname],
              fullname_reverse: [n[:_source][:family].presence, n[:_source][:given].presence].compact.join(", ")
            }
          }
        end

        def format_users
          @results.map{ |n|
            user = User.find(n[:_source][:id])
            lifespan = user.wikidata ? format_lifespan(user) : nil
            { id: n[:_source][:id],
              score: n[:_score],
              orcid: n[:_source][:orcid],
              wikidata: n[:_source][:wikidata],
              fullname: n[:_source][:fullname],
              fullname_reverse: n[:_source][:fullname_reverse],
              thumbnail: n[:_source][:thumbnail],
              lifespan: lifespan
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
          if user.date_born_precision == "day"
            born = user.date_born.to_formatted_s(:long)
          elsif user.date_born_precision == "month"
            born = user.date_born.to_formatted_s(:month_and_year)
          elsif user.date_born_precision == "year"
            born = user.date_born.to_formatted_s(:year)
          else
            born = "?"
          end

          if user.date_died_precision == "day"
            died = user.date_died.to_formatted_s(:long)
          elsif user.date_died_precision == "month"
            died = user.date_died.to_formatted_s(:month_and_year)
          elsif user.date_died_precision == "year"
            died = user.date_died.to_formatted_s(:year)
          else
            died = "?"
          end

          "(" + ["b. " + born, "d. " + died].join(" &ndash; ") + ")"
        end

      end
    end
  end
end
