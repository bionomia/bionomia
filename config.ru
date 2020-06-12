require './application.rb'
require 'sinatra'

set :run, true
set :environment, :production

run Rack::URLMap.new('/' => BIONOMIA, '/sidekiq' => Sidekiq::Web)
