require './application.rb'
require 'sinatra'

set :environment, :production
disable :run, :reload

Sidekiq::Web.use Rack::Session::Cookie, key: 'rack.session',
                           path: '/',
                           secret: Settings.orcid.key,
                           domain: Settings.cookie_domain,
                           same_site: :lax

run Rack::URLMap.new('/' => BIONOMIA, '/sidekiq' => Sidekiq::Web)
