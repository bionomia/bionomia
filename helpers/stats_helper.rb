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

      end
    end
  end
end
