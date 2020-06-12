# encoding: utf-8

# monkey patch Sinatra::Cacher because loading html fragment throws error
# Encoding::CompatibilityError - incompatible character encodings: ASCII-8BIT and UTF-8
module Sinatra
  module Cacher
    def cache_get_tag(tag)
      return nil if !tag
      path = cache_gen_path(tag)
      return nil unless File.file?(path)
      time, content_type, content = File.open(path, 'rb') do |f|
        [
          f.gets.chomp.to_i,
          f.gets.chomp,
          f.read.force_encoding(Encoding.default_internal)
        ]
      end
      if content_type == 'marshal'
        content = Marshal.load(content)
        content_type = nil
      elsif content_type.empty?
        content_type = nil
      end
      [content, time, content_type]
    end
  end
end
