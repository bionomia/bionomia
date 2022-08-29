require './application.rb'
require 'sinatra'

set :environment, :production
disable :run, :reload

Sidekiq::Web.use Rack::Session::Cookie, key: 'rack.session',
                           path: '/',
                           secret: Settings.orcid.key,
                           domain: Settings.cookie_domain,
                           same_site: :lax

if defined?(PhusionPassenger)
 PhusionPassenger.require_passenger_lib 'rack/out_of_band_gc'

 # Trigger out-of-band GC every 5 requests.
 use PhusionPassenger::Rack::OutOfBandGc, 5
end

run Rack::URLMap.new('/' => BIONOMIA, '/sidekiq' => Sidekiq::Web)
