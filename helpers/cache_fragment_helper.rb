# encoding: utf-8

module Sinatra
  module Cacher
    module Helpers

      # Monkey-patch the Sinatra Cacher method to force_encode the content
      def cache_fragment(tag, opts={}, &blk)
        raise "You must install sinatra-outputbuffer, require sinatra/outputbuffer, and register Sinatra::OutputBuffer to use cache_fragment" unless respond_to?(:capture_html)
        raise "No block given to cache_fragment" unless block_given?
        tag = "fragments/#{tag}"
        unless opts[:overwrite]
          content, = settings.cache_get_tag(tag)
          if !content.nil?
            content = content.force_encoding(Encoding::UTF_8)
          end
          return block_is_template?(blk) ? concat_content(content) : content if content
        end
        content = capture_html(&blk)
        settings.cache_put_tag(tag, content)
        if !content.nil?
          content = content.force_encoding(Encoding::UTF_8)
        end
        block_is_template?(blk) ? concat_content(content) : content
      end

    end
  end
end
