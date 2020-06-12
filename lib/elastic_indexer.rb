# encoding: utf-8

module Bionomia
  class ElasticIndexer

    def initialize(opts = {})
      @client = Elasticsearch::Client.new url: Settings.elastic.server, request_timeout: 5*60
      @settings = { index: "index" }.merge(opts)
    end

    def delete_index
      if @client.indices.exists index: @settings[:index]
        @client.indices.delete index: @settings[:index]
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
      @client.indices.create index: @settings[:index], body: config
    end

    def refresh_index
      @client.indices.refresh index: @settings[:index]
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
      @client.bulk index: @settings[:index], refresh: false, body: documents
    end

    def import
    end

    def get(d)
      begin
        @client.get index: @settings[:index], id: d.id
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        nil
      end
    end

    def add(d)
      @client.index index: @settings[:index], id: d.id, body: document(d)
    end

    def update(d)
      doc = { doc: document(d) }
      @client.update index: @settings[:index], id: d.id, body: doc
    end

    def delete(d)
      @client.delete index: @settings[:index], id: d.id
    end

    def document(d)
      { id: d.id }
    end

  end
end
