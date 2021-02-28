# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module UserOccurrenceController

        def self.registered(app)

          app.post '/profile/user-occurrence/bulk.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            action = req[:action] rescue nil
            visible = req[:visible] rescue true
            occurrence_ids = req[:occurrence_ids].split(",")
            if !visible
              UserOccurrence.where({ occurrence_id: occurrence_ids, user_id: @user[:id] })
                            .destroy_all
            end
            data = occurrence_ids.map{|o| {
                user_id: @user.id,
                occurrence_id: o.to_i,
                created_by: @user.id,
                action: action,
                visible: visible
              }
            }
            UserOccurrence.transaction do
              UserOccurrence.import data, batch_size: 250, validate: false, on_duplicate_key_ignore: true
            end
            { message: "ok" }.to_json
          end

          app.post '/profile/user-occurrence/:occurrence_id.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            action = req[:action] rescue nil
            visible = req[:visible] rescue true
            uo = UserOccurrence.new
            uo.user_id = @user.id
            uo.occurrence_id = params[:occurrence_id]
            uo.created_by = @user.id
            uo.action = action
            uo.visible = visible
            uo.save
            { message: "ok", id: uo.id }.to_json
          end

          app.put '/profile/user-occurrence/bulk.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            action = req[:action] rescue nil
            visible = req[:visible] rescue true
            ids = req[:occurrence_ids].split(",")
            UserOccurrence.where({ id: ids, user_id: @user.id })
                          .update_all({ action: action, visible: visible })
            { message: "ok" }.to_json
          end

          app.put '/profile/user-occurrence/:id.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            uo = UserOccurrence.find_by({ id: params[:id], user_id: @user.id })
            uo.action = req[:action] ||= nil
            uo.visible = req[:visible] ||= true
            uo.save
            { message: "ok" }.to_json
          end

          app.delete '/profile/user-occurrence/bulk.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            req = JSON.parse(request.body.read).symbolize_keys
            ids = req[:ids].split(",")
            UserOccurrence.where({ id: ids, user_id: @user.id })
                          .delete_all
            { message: "ok" }.to_json
          end

          app.delete '/profile/user-occurrence/:id.json' do
            protected!
            content_type "application/json", charset: 'utf-8'
            UserOccurrence.where({ id: params[:id], user_id: @user.id })
                          .delete_all
            { message: "ok" }.to_json
          end

        end

      end
    end
  end
end
