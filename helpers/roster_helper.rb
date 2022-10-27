# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module RosterHelper

        def roster
          @pagy, @results = pagy(User.where(is_public: true).order(:family))
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
                      .order(:family)
          @pagy, @results = pagy(users)
        end

        def admin_roster
          data = User.order(visited: :desc, family: :asc)
          if params[:order] && User.column_names.include?(params[:order]) && ["asc", "desc"].include?(params[:sort])
            data = User.order("#{params[:order]} #{params[:sort]}")
          end
          @pagy, @results = pagy(data, items: 100)
        end

      end
    end
  end
end
