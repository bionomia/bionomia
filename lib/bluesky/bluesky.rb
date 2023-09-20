# encoding: utf-8

module Bionomia
  class Bluesky

    def initialize
      @session = get_session
      @post_item = {}
    end

    def add_text(text:)
      @post_item.merge!({
         "$type": "app.bsky.feed.post",
         text: text,
         createdAt: Time.now.iso8601,
         langs: ["en-US"]
      })
      if text.include?("http")
        @post_item.merge!({
          facets: []
        })
        URI.extract(text).each do |url|
          @post_item[:facets] << {
            index: {
              byteStart: text.index(url),
              byteEnd: text.index(url) + url.length
            },
            features: [
              {
                "$type": "app.bsky.richtext.facet#link",
                "uri": url
              }
            ]
          }
        end
      end
    end

    def add_image(image_url:, alt_text:) 
      url = Settings.bluesky.endpoint + "com.atproto.repo.uploadBlob"
      image = download_image(uri: image_url)
      response = RestClient::Request.execute(
        method: :post,
        headers: { authorization: "Bearer #{@session[:accessJwt]}", content_type: "image/png" },
        url: url,
        payload: image.to_blob
      )
      image.destroy!
      if !@post_item.key?(:embed)
        add_embed
      end
      @post_item[:embed][:images] << { alt: alt_text, image: JSON.parse(response.body, symbolize_names: true)[:blob] }
    end

    def post
      raise "No text in the post!" if @post_item.empty?
      begin
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
      rescue Exception => e
        puts "Post to Bluesky failed"
      end
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

    def download_image(uri:)
      image = MiniMagick::Image.open(uri)
      image.resize "600x600"
      image.strip
      image.format "png"
      image
    end

    def add_embed
      @post_item.merge!({
        embed: {
          "$type": "app.bsky.embed.images",
          images: []
        }
      })
    end

  end
end
