# encoding: utf-8

module Sinatra
   module Bionomia
     module SidekiqSecurity

      def self.registered(app)
         app.before do
            if session[:omniauth]
               @user = User.find(session[:omniauth].id) rescue nil
               redirect "/admin" if !@user || !@user.is_admin?
            else
               redirect "/admin"
            end
         end
      end

     end
   end
end