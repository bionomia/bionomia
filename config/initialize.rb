# encoding: utf-8

module Sinatra
  module Bionomia
    module Config
      module Initialize

        def self.registered(app)
          app.use Rack::Locale
          app.use Rack::MethodOverride
          app.use Rack::JSONBodyParser, verbs: ['GET', 'PUT', 'POST', 'DELETE']

          secure = false
          if app.environment == :production
            secure = true
            app.use Rack::Tracker do
              handler :google_global, { trackers: [ { id: Settings.google.analytics } ] }
            end
          end

          # This is already in config.ru so why we do again???
          app.use Rack::Session::Cookie, key: 'rack.session',
                                     path: '/',
                                     secret: Settings.orcid.key * 4,
                                     domain: Settings.cookie_domain,
                                     expire_after: 2592000,
                                     httpdonly: true,
                                     secure: secure,
                                     same_site: :lax
                                     
          app.use Rack::Protection::AuthenticityToken
          app.use Sinatra::Bionomia::SidekiqSecurity

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
                :redirect_uri => Settings.base_url + '/auth/zenodo/callback'
              },
              :token_params => {
                :client_id => Settings.zenodo.key,
                :client_secret => Settings.zenodo.secret
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

          Sidekiq.configure_server do |config|
            config.redis = { 
              url: Settings.redis.url,
              size: Settings.redis.size,
              timeout: 5,
              ssl_params: {
                verify_mode: OpenSSL::SSL::VERIFY_NONE
              }
            }
            config.average_scheduled_poll_interval = 30
          end
          
          Sidekiq.configure_client do |config|
            config.redis = {
              url: Settings.redis.url,
              size: Settings.redis.size,
              timeout: 5,
              ssl_params: {
                verify_mode: OpenSSL::SSL::VERIFY_NONE
              }
            }
          end

          app.use Sinatra::Bionomia::Model::QueryCache

        end

      end
    end
  end
end
