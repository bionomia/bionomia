#!/usr/bin/env ruby
# encoding: utf-8

require File.dirname(__FILE__) + '/environment.rb'

class BIONOMIA < Sinatra::Base
  register Config
  register Sinatra::I18nSupport
  register Sinatra::Cacher
  register Sinatra::Flash
  register Sinatra::Namespace
  register Sinatra::OutputBuffer
  register Sinatra::Bionomia::Config::Initialize
  register Sinatra::Bionomia::Helper::Initialize
  register Sinatra::Bionomia::Route::Initialize
  register Sinatra::Bionomia::Model::Initialize

  set :root, File.dirname(__FILE__)
  set :haml, :format => :html5
  set :public_folder, 'public'
  set :cache_enabled_in, [:development, :production]
  set :protection, :except => [:json_csrf, :remote]
  set :strict_paths, false

  offline_settings = KeyValue.mget(["off_datetime", "off_duration", "online_when"]) rescue {}
  if offline_settings
    Settings.add_source!({
      off_datetime: offline_settings[:off_datetime],
      off_duration: offline_settings[:off_duration],
      online_when: offline_settings[:online_when]
    })
    Settings.reload!
  end

  load_locales File.join(root, 'config', 'locales')
  I18n.available_locales = [:en, :fr, :es, :pt, :de, :zh, :cs]

  include Pagy::Backend
  include Pagy::Frontend
  Pagy::DEFAULT[:limit] = 30
  Pagy::DEFAULT[:size]  = 7
  Pagy::DEFAULT[:overflow] = :last_page

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

  not_found do
    haml :oops if !content_type
  end

  error do
    haml :error if !content_type
  end

  before do
    locale = request.host.split('.')[0]
    if I18n.available_locales.include? locale.to_sym
      I18n.locale = locale
    elsif authorized?
      user_preferred_locale
    end
  end

  run! if app_file == $0
end
