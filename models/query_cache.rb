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
          response = nil
          ActiveRecord::Base.cache do
            response = @app.call(env)
          end
          response
        end

      end
    end
  end
end
