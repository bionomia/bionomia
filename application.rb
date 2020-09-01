#!/usr/bin/env ruby
# encoding: utf-8

require File.dirname(__FILE__) + '/environment.rb'

class BIONOMIA < Sinatra::Base
  set :root, File.dirname(__FILE__)
  set :haml, :format => :html5
  set :public_folder, 'public'
  set :show_exceptions, false

  register Sinatra::I18nSupport
  load_locales File.join(root, 'config', 'locales')
  I18n.available_locales = [:en, :fr]

  register Config

  register Sinatra::Cacher
  register Sinatra::Flash
  register Sinatra::OutputBuffer
  set :cache_enabled_in, [:development, :production]

  use Rack::Locale
  use Rack::MethodOverride

  use Rack::Session::Cookie, key: 'rack.session',
                             path: '/',
                             secret: Settings.orcid.key
  use Rack::Protection, reaction: :drop_session, use: :authenticity_token

  use OmniAuth::Builder do
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

  include Pagy::Backend
  include Pagy::Frontend
  Pagy::VARS[:items] = 30

  if environment == :production
    use Rack::Tracker do
      handler :google_analytics, { tracker: Settings.google.analytics }
    end
  end

  helpers Sinatra::ContentFor
  helpers Sinatra::Bionomia::Formatters

  Sinatra::Bionomia::Helper.constants.sort.each do |h|
    if Sinatra::Bionomia::Helper.const_get(h).is_a?(Module)
      helpers "Sinatra::Bionomia::Helper::#{h}".constantize
    end
  end

  Sinatra::Bionomia::Controller.constants.sort.each do |c|
    if Sinatra::Bionomia::Controller.const_get(c).is_a?(Module)
      register "Sinatra::Bionomia::Controller::#{c}".constantize
    end
  end

  register Sinatra::Bionomia::Model::Initialize
  use Sinatra::Bionomia::Model::QueryCache

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
    end
  end

  run! if app_file == $0
end
