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
          return if authorized? && !banned?
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

        def banned?
          destroyed_user = DestroyedUser.find_by_identifier(@user.identifier)
          (destroyed_user && destroyed_user.redirect_to.blank?) ? true : false
        end

        def check_banned(identifier)
          destroyed_user = DestroyedUser.find_by_identifier(identifier)
          if !destroyed_user.nil? && destroyed_user.redirect_to.blank?
            halt 410, haml(:oops)
          end
        end

      end
    end
  end
end
