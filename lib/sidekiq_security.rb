# encoding: utf-8

module Sinatra
   module Bionomia
      class SidekiqSecurity

         def initialize(app, options = nil)
            @app = app
         end

         def call(env)
            request = Rack::Request.new(env)
            if request.path == "/admin/sidekiq"
               user = User.find(request.session["omniauth"].id) rescue nil
               if user && user.is_admin?
                  @app.call(env)
               else
                  [302, { "location" => "/admin" }, []]
               end
            else
               @app.call(env)
            end
         end

      end
   end
end