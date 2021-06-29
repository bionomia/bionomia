#!/usr/bin/env ruby
# encoding: utf-8

require File.dirname(__FILE__) + '/environment.rb'

class BIONOMIA < Sinatra::Base
  set :root, File.dirname(__FILE__)
  set :haml, :format => :html5
  set :public_folder, 'public'
  set :cache_enabled_in, [:development, :production]
  set :protection, :except => [:json_csrf, :remote]
  set :strict_paths, false

  register Config
  register Sinatra::I18nSupport
  register Sinatra::Cacher
  register Sinatra::Flash
  register Sinatra::OutputBuffer
  register Sinatra::Bionomia::Config::Initialize
  register Sinatra::Bionomia::Helper::Initialize
  register Sinatra::Bionomia::Controller::Initialize
  register Sinatra::Bionomia::Model::Initialize

  load_locales File.join(root, 'config', 'locales')
  I18n.available_locales = [:en, :fr, :es, :pt, :de]

  include Pagy::Backend
  include Pagy::Frontend
  Pagy::VARS[:items] = 30

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
