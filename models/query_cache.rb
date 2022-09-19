# encoding: utf-8

module Sinatra
  module Bionomia
    module Model
      class QueryCache

        def initialize(app)
          ActiveRecord::Base.connection.enable_query_cache!
          @app = app
        end

        def call(env)
          if is_static_file?(env)
            @app.call(env)
          else
            response = nil
            ActiveRecord::Base.cache do
              response = @app.call(env)
            end
            response
          end
        end

        def is_static_file?(env)
          env['PATH_INFO'] =~ /\.[a-z]{2,4}$/
        end

      end
    end
  end
end
