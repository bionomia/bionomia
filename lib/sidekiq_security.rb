# encoding: utf-8

module Sinatra
   module Bionomia
      module SidekiqSecurity

         def self.registered(app)
            app.before do
               redirect "/admin" if !session[:omniauth]
               if !session[:sidekiqauth]
                  user = User.find(session[:omniauth].id) rescue nil
                  session[:sidekiqauth] = true if user && user.is_admin?
               end
               redirect "/admin" if !session[:sidekiqauth]
            end
         end

      end
   end
end