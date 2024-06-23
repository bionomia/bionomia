# encoding: utf-8

module Bionomia
  class ElasticIndexer

    def initialize(opts = {})
      @settings = { index: "index" }.merge(opts)
    end

    def client
      @client ||= Elasticsearch::Client.new \
            url: Settings.elastic.server,
            request_timeout: 5*60,
            retry_on_failure: true,
            reload_on_failure: true,
            reload_connections: 1_000,
            adapter: :typhoeus
    end

    def cluster_health
      response = client.cat.health format: 'json', v: true
      response[0]
    end

    def cluster_stats
      client.cluster.stats
    end

    def health
      response = client.cluster.health index: @settings[:index], level: "indices", local: true
      response["indices"][@settings[:index]]
    end

    def stats
      response = client.indices.stats index: @settings[:index]
      response["indices"][@settings[:index]]
    end

    def disk_usage
      usage = client.indices.disk_usage index: @settings[:index], run_expensive_tasks: true
      usage[@settings[:index]]["store_size"]
    end

    def count(body: {})
      response = client.count index: @settings[:index], body: body
      response["count"]
    end

    def delete_index
      if client.indices.exists index: @settings[:index]
        client.indices.delete index: @settings[:index]
      end
    end

    def create_index
      config = {
        mappings: {
          properties: {
            id: { type: 'integer', index: false }
          }
        }
      }
      client.indices.create index: @settings[:index], body: config
    end

    def refresh_index
      client.indices.refresh index: @settings[:index]
    end

    def bulk(batch)
      documents = []
      batch.each do |d|
        documents << {
          index: {
            _id: d.id,
            data: document(d)
          }
        }
      end
      if !documents.empty?
        client.bulk index: @settings[:index], refresh: false, body: documents
      end
    end

    def import
    end

    def get(d)
      begin
        client.get index: @settings[:index], id: d.id
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        nil
      end
    end

    def add(d)
      client.index index: @settings[:index], id: d.id, body: document(d)
    end

    def update(d)
      doc = { doc: document(d) }
      client.update index: @settings[:index], id: d.id, body: doc
    end

    def delete(d)
      client.delete index: @settings[:index], id: d.id
    end

    def document(d)
      { id: d.id }
    end

    def analyze(analyzer:, text:)
      client.indices.analyze(
        index: @settings[:index],
        body: {
          analyzer: analyzer,
          text: text
        }
      )
    end

  end
end
