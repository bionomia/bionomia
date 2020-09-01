# encoding: utf-8

module Sinatra
  module Bionomia
    module Config
      module Initialize

        def self.registered(app)
          app.use Rack::Locale
          app.use Rack::MethodOverride

          app.use Rack::Session::Cookie, key: 'rack.session',
                                     path: '/',
                                     secret: Settings.orcid.key
          app.use Rack::Protection, reaction: :drop_session, use: :authenticity_token

          app.use OmniAuth::Builder do
            provider :orcid, Settings.orcid.key, Settings.orcid.secret,
              :authorize_params => {
                :scope => '/authenticate'
              },
              :client_options => {
                :site => Settings.orcid.site,
                :authorize_url => Settings.orcid.authorize_url,
                :token_url => Settings.orcid.token_url,
                :token_method => :post,
                :scope => '/authenticate'
              }

            provider :zenodo, Settings.zenodo.key, Settings.zenodo.secret,
              :sandbox => Settings.zenodo.sandbox,
              :authorize_params => {
                :client_id => Settings.zenodo.key,
                :redirect_uri => Settings.base_url + '/auth/zenodo/callback'
              },
              :client_options => {
                :site => Settings.zenodo.site,
                :authorize_url => Settings.zenodo.authorize_url,
                :token_url => Settings.zenodo.token_url,
                :token_method => :post,
                :scope => 'deposit:write deposit:actions',
                :redirect_uri => Settings.base_url + '/auth/zenodo/callback'
              }
           end

           app.use Sinatra::Bionomia::Model::QueryCache

           if app.environment == :production
             app.use Rack::Tracker do
               handler :google_analytics, { tracker: Settings.google.analytics }
             end
           end

        end

      end
    end
  end
end
