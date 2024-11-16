class OccurrenceCount < ActiveRecord::Base
  belongs_to :occurrence

  def has_candidate?
    collectors, whole_network = collector_network

    return false if whole_network.size < 2

    partial_network = whole_network - collectors

    body = occurrence.recorders
                     .map{|a| { search: build_name_query(a.fullname) } }
    return false if body.empty?
    response = ::Bionomia::ElasticUser.new.msearch(body: body)
    response["responses"].each do |response|
      response["hits"]["hits"].each do |hit|
        if hit["_score"] > 50 && partial_network.include?(hit["_id"].to_i)
          return true
        end
      end
    end

    return false
  end

  private

  def collector_network
    collectors = occurrence.user_recordings.pluck(:user_id).uniq rescue []
    whole_network = []
    response = ::Bionomia::ElasticUser.new.mget(ids: collectors) rescue nil
    begin
      response["docs"].each do |doc|
        results = doc["_source"]
        whole_network << results["co_collectors"].map{|a| a["id"]}
      end
    rescue
    end

    [collectors, whole_network.flatten.uniq]
  end

  def build_name_query(search)
    {
      query: {
        bool: {
          must: [
            {
              multi_match: {
                query:      search,
                type:       :cross_fields,
                analyzer:   :fullname_index,
                fields:     ["family^5", "given^3", "fullname", "other_names", "*.edge"]
              }
            }
          ],
          filter: [
            { term: { has_occurrences: true } }
          ]
        }
      },
      fields: ["id"],
      from: 0,
      size: 3,
      "_source": false
    }
  end

end
