class OccurrenceCount < ActiveRecord::Base
  belongs_to :occurrence

  def has_candidate?
    client.transport.reload_connections!

    collectors, whole_network = collector_network

    return false if whole_network.size < 2

    partial_network = whole_network - collectors

    body = occurrence.recorders
                     .map{|a| { search: build_name_query(a.fullname) } }
    response = client.msearch index: Settings.elastic.user_index, body: body
    response["responses"].each do |response|
      response["hits"]["hits"].each do |hit|
        if hit["_score"] > 40 && partial_network.include?(hit["_source"]["id"])
          return true
        end
      end
    end

    return false
  end

  private

  def collector_network
    collectors = occurrence.user_recordings.pluck(:user_id).uniq

    response = client.mget index: Settings.elastic.user_index, body: { ids: collectors }

    whole_network = []
    response["docs"].each do |doc|
      results = doc["_source"]
      whole_network << results["co_collectors"].map{|a| a["id"]}
    end

    [collectors, whole_network.flatten.uniq]
  end

  def build_name_query(search)
    {
      query: {
        multi_match: {
          query:      search,
          type:       :cross_fields,
          analyzer:   :fullname_index,
          fields:     ["family^5", "given^3", "fullname", "other_names", "*.edge"]
        }
      },
      from: 0,
      size: 3
    }
  end

  def client
    @client ||= Elasticsearch::Client.new(
      url: Settings.elastic.server,
      request_timeout: 5*60,
      retry_on_failure: true,
      reload_on_failure: true,
      adapter: :typhoeus
    )
  end

end
