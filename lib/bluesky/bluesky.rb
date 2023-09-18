# encoding: utf-8

module Bionomia
  class Bluesky

    def initialize
      @session = get_session
      @post_item = {}
      @image_items = []
    end

    def add_text(text:)
      @post_item = {
         "$type": "app.bsky.feed.post",
         text: text,
         createdAt: Time.now.iso8601,
         langs: ["en-US"]
      }
    end

    def add_image(image:) 
      #TODO: get image, make tmp object, resize it, upload it, flush it and add to @image_items array
      #TODO: add an embed object to @post_item if not present, otherwise add to images array there.
      # See https://atproto.com/blog/create-post
    end

    def post
      #TODO: throw exception of @post_item is an empty object
      url = Settings.bluesky.endpoint + "com.atproto.repo.createRecord"
      payload = {
         repo: @session[:did],
         collection: "app.bsky.feed.post",
         record: @post_item
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
