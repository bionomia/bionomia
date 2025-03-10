require './application.rb'
require 'sinatra'

set :environment, :production
disable :run, :reload

Sidekiq::Web.use Rack::Session::Cookie, key: 'rack.session',
                           path: '/',
                           secret: Settings.orcid.key * 4,
                           domain: Settings.cookie_domain,
                           expire_after: 2592000,
                           httpdonly: true,
                           same_site: :lax
Sidekiq::Web.use Rack::Protection::AuthenticityToken

if defined?(Sidekiq::Web)
   #Sidekiq::Web.configure {|cfg| cfg.register(Sinatra::Bionomia::SidekiqSecurity, name: 'SidekiqSecurity', tab: 'security', index: 'admin') }
end

if defined?(PhusionPassenger)
   PhusionPassenger.require_passenger_lib 'rack/out_of_band_gc'

   # Trigger out-of-band GC every 5 requests.
   use PhusionPassenger::Rack::OutOfBandGc, 5
end

run Rack::URLMap.new('/' => BIONOMIA, '/admin/sidekiq' => Sidekiq::Web)