# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module StatsHelper

        def stats_claims
          data = UserOccurrence.select("YEAR(created) AS year, MONTH(created) AS month, count(*) AS sum")
                               .where.not(created_by: User::BOT_IDS)
                               .where(visible: true)
                               .where("created_by = user_id")
                               .group("YEAR(created), MONTH(created)")
                               .order("YEAR(created), MONTH(created)")
          total = 0
          data.map{|d| [d.year, d.month, total += d.sum] }
        end

        def stats_attributions
          data = UserOccurrence.select("YEAR(created) AS year, MONTH(created) AS month, count(*) AS sum")
                               .where.not(created_by: User::BOT_IDS)
                               .where(visible: true)
                               .where("created_by <> user_id")
                               .group("YEAR(created), MONTH(created)")
                               .order("YEAR(created), MONTH(created)")
          total = 0
          data.map{|d| [d.year, d.month, total += d.sum] }
        end

        def stats_rejected
          data = UserOccurrence.select("YEAR(created) AS year, MONTH(created) AS month, count(*) AS sum")
                               .where.not(created_by: User::BOT_IDS)
                               .where(visible: false)
                               .group("YEAR(created), MONTH(created)")
                               .order("YEAR(created), MONTH(created)")
          total = 0
          data.map{|d| [d.year, d.month, total += d.sum] }
        end

        def stats_profiles
          data = User.select("YEAR(created) AS year, MONTH(created) AS month, count(wikidata) AS wikidata_sum, count(orcid) AS orcid_sum")
                     .group("YEAR(created), MONTH(created)")
                     .order("YEAR(created), MONTH(created)")
          wikidata_total = 0
          orcid_total = 0
          data.map{|d| [d.year, d.month, (wikidata_total += d.wikidata_sum), (orcid_total += d.orcid_sum)] }
        end

        def stats_orcid
          User.select("COUNT(*) AS total, SUM(IF(visited, 1, 0)) AS visited, SUM(IF(is_public = true, 1, 0)) AS public, SUM(IF(zenodo_doi, 1, 0)) AS doi")
              .where.not(orcid: nil)
              .first
        end

        def stats_wikidata
          User.select("COUNT(*) AS total, SUM(IF(is_public = true, 1, 0)) AS public")
              .where.not(wikidata: nil)
              .first
        end

      end
    end
  end
end
