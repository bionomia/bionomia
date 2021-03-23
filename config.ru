require './application.rb'
require 'sinatra'

set :environment, :production
disable :run, :reload

run Rack::URLMap.new('/' => BIONOMIA, '/sidekiq' => Sidekiq::Web)
