class OccurrenceCount < ActiveRecord::Base
  belongs_to :occurrence

  def update_candidate

    client = Elasticsearch::Client.new(
      url: Settings.elastic.server,
      request_timeout: 5*60,
      retry_on_failure: true,
      reload_on_failure: true,
      adapter: :typhoeus
    )
    client.transport.reload_connections!

    collectors = []
    whole_network = []
    occurrence.user_recordings.each do |recordings|
      user = recordings.user
      collectors << user.id
      begin
        response = client.get index: Settings.elastic.user_index, id: user.id
        results = response["_source"].deep_symbolize_keys
        whole_network << results[:co_collectors].map{|a| a[:id]}
      rescue
      end
    end

    return if whole_network.flatten.uniq.size < 2

    partial_network = whole_network.flatten.uniq - collectors.uniq

    query = Class.new
    query.extend Sinatra::Bionomia::Helper::QueryHelper

    agents = occurrence.recorders.map{|a| Agent.find(a.id).fullname }

    agents.each do |agent|
      body = query.build_name_query(agent)
      response = client.search index: Settings.elastic.user_index, from: 0, size: 3, body: body
      results = response["hits"].deep_symbolize_keys
      results[:hits].each do |hit|
        if hit[:_score] > 40 && partial_network.include?(hit[:_source][:id])
          update(candidate: true )
          return
        end
      end
    end

  end

end
