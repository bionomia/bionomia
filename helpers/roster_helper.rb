# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module RosterHelper

        def roster
          @pagy, @results = pagy(User.where(is_public: true).order(:family))
        end

        def help_roster
          users = User.where.not(id: User::BOT_IDS)
                      .where(Arel.sql("CONCAT(family, label) IS NOT NULL"))
                      .order(Arel.sql("LOWER(CONCAT(family, label))"))
          @pagy, @results = pagy(users)
        end

        def roster_gallery
          users = User.where(is_public: true)
                      .where.not(image_url: nil)
                      .order(:family)
          @pagy, @results = pagy(users)
        end

        def roster_signatures
          users = User.where(is_public: true)
                      .where.not(signature_url: nil)
                      .order(:date_born)
          @pagy, @results = pagy(users)
        end

        def admin_roster
          data = User.order(visited: :desc, family: :asc)
          if params[:order] && User.column_names.include?(params[:order]) && ["asc", "desc"].include?(params[:sort])
            data = User.order("#{params[:order]} #{params[:sort]}")
          end
          @pagy, @results = pagy(data, limit: 100)
        end

        def destroyed_users
          data = DestroyedUser.order(identifier: :asc)
          if params[:order] && DestroyedUser.column_names.include?(params[:order]) && ["asc", "desc"].include?(params[:sort])
            data = DestroyedUser.order("#{params[:order]} #{params[:sort]}")
          end
          @pagy, @results = pagy(data, limit: 250)
        end

      end
    end
  end
end
