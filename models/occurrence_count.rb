class OccurrenceCount < ActiveRecord::Base
  belongs_to :occurrence

  def has_candidate?
    client.transport.reload_connections!

    collectors, whole_network = collector_network

    return false if whole_network.size < 2

    partial_network = whole_network - collectors

    agents = occurrence.recorders.map{|a| a.fullname }
    agents.each do |agent|
      body = build_name_query(agent)
      response = client.search index: Settings.elastic.user_index, from: 0, size: 3, body: body
      results = response["hits"].deep_symbolize_keys
      results[:hits].each do |hit|
        if hit[:_score] > 40 && partial_network.include?(hit[:_source][:id])
          return true
        end
      end
    end

    return false
  end

  private

  def collector_network
    collectors = occurrence.user_recordings.pluck(:user_id).uniq
    whole_network = []
    collectors.each do |user_id|
      begin
        response = client.get index: Settings.elastic.user_index, id: user_id
        results = response["_source"].deep_symbolize_keys
        whole_network << results[:co_collectors].map{|a| a[:id]}
      rescue
      end
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
          fields:     ["family^5", "given^3", "fullname", "other_names", "*.edge"],
        }
      }
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
