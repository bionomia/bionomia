# encoding: utf-8

module Bionomia
  class Bluesky

    def initialize
      @session = get_session
    end

    def add_file(file_path:, file_name: nil)
    end

    def post(text:)
      url = Settings.bluesky.endpoint + "com.atproto.repo.createRecord"
      item = {
         "$type": "app.bsky.feed.post",
         text: text,
         createdAt: Time.now.iso8601,
         langs: ["en-US"],
      }
      payload = {
         repo: @session[:did],
         collection: "app.bsky.feed.post",
         record: item
      }
      response = RestClient::Request.execute(
         method: :post,
         headers: { authorization: "Bearer #{@session[:accessJwt]}", content_type: "application/json" },
         url: url,
         payload: payload.to_json
       )
       JSON.parse(response.body, symbolize_names: true)
    end

    private

    def get_session
      url = Settings.bluesky.endpoint + "com.atproto.server.createSession"
      payload = {
         identifier: Settings.bluesky.handle,
         password: Settings.bluesky.password
      }
      response = RestClient::Request.execute(
         method: :post,
         headers: { content_type: "application/json" },
         url: url,
         payload: payload.to_json
       )
       JSON.parse(response.body, symbolize_names: true)
    end

  end
end
