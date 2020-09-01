# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module SecurityHelper

        def set_session
          if session[:omniauth]
            @user = User.find(session[:omniauth].id) rescue nil
          end
        end

        def protected!
          return if authorized?
          halt 401, haml(:not_authorized)
        end

        def authorized?
          !@user.nil?
        end

        def admin_protected!
          return if admin_authorized?
          halt 401, haml(:not_authorized)
        end

        def admin_authorized?
          !@user.nil? && is_admin?
        end

        def is_public?
          @user.is_public ? true : false
        end

        def is_user_public?
          @admin_user.is_public? ? true : false
        end

        def is_admin?
          @user && @user.is_admin? ? true : false
        end

      end
    end
  end
end
