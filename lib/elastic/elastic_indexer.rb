# encoding: utf-8

module Bionomia
  class ElasticIndexer

    def initialize
      client
    end

    def index
      "index"
    end

    def config
      {
        mappings: {
          properties: {
            id: { type: 'integer', index: false }
          }
        }
      }
    end

    def exists?
      client.indices.exists index: index
    end

    def count(body: {})
      response = client.count index: index, body: body
      response["count"]
    end

    def delete_index
      if client.indices.exists index: index
        client.indices.delete index: index
      end
    end

    def create_index
      client.indices.create index: index, body: config
    end

    def refresh_index
      client.indices.refresh index: index
    end

    def ping
      client.ping
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
        client.bulk index: index, refresh: false, body: documents
      end
    end

    def import
    end

    def get(d)
      begin
        client.get index: index, id: d.id
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        nil
      end
    end

    def mget(ids: [])
      client.mget index: index, body: { ids: ids }
    end

    def add(d)
      client.index index: index, id: d.id, body: document(d)
    end

    def update(d)
      doc = { doc: document(d) }
      client.update index: index, id: d.id, body: doc
    end

    def delete(d)
      client.delete index: index, id: d.id
    end

    def search(from: 0, size: 10, body: {}, scroll: nil)
      if scroll
        client.search index: index, size: size, body: body, scroll: scroll
      else
        client.search index: index, from: from, size: size, body: body
      end
    end

    def msearch(body: {})
      client.msearch index: index, body: body
    end

    def scroll(scroll: '5m', scroll_id: 0)
      client.scroll(scroll: '5m', body: { scroll_id: scroll_id })
    end

    def document(d)
      { id: d.id }
    end

    def analyze(analyzer:, text:)
      client.indices.analyze(
        index: index,
        body: {
          analyzer: analyzer,
          text: text
        }
      )
    end

    def cluster_health
      response = client.cat.health format: 'json', v: true
      response[0]
    end

    def cluster_stats
      client.cluster.stats
    end

    def health
      response = client.cluster.health index: index, level: "indices", local: true
      response["indices"][index]
    end

    def stats
      response = client.indices.stats index: index
      response["indices"][index]
    end

    def disk_usage
      usage = client.indices.disk_usage index: index, run_expensive_tasks: true
      usage[index]["store_size"]
    end

    private

    def client
      @client ||= Elasticsearch::Client.new \
            url: Settings.elastic.server,
            request_timeout: 5*60,
            retry_on_failure: true,
            reload_on_failure: true,
            reload_connections: 1_000,
            adapter: :typhoeus
    end

  end
end
