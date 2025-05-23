require 'bundler'
require 'bundler/setup'
require 'ostruct'
require 'logger'
require 'trilogy'
require 'active_record'
require 'active_record_union'
require 'activerecord-import'
require 'active_support/all'
require 'action_view'
require 'addressable/uri'
require 'charlock_holmes'
require 'counter_culture'
require 'digest'
require 'down'
require 'rest_client'
require 'json'
require 'sanitize'
require 'htmlentities'
require 'i18n'
require 'iso_country_codes'
require 'tilt/haml'
require 'sinatra/base'
require 'sinatra/content_for'
require 'sinatra/cacher'
require 'sinatra/flash'
require 'sinatra/namespace'
require 'sinatra/outputbuffer'
require 'sinatra/support/i18nsupport'
require 'config'
require 'yaml'
require 'namae'
require 'elasticsearch'
require 'mini_magick'
require 'pagy'
require 'pagy/extras/arel'
require 'pagy/extras/array'
require 'pagy/extras/bootstrap'
require 'pagy/extras/countless'
require 'pagy/extras/elasticsearch_rails'
require 'pagy/extras/i18n'
require 'pagy/extras/metadata'
require 'pagy/extras/overflow'
require 'parallel'
require 'chronic'
require 'faraday'
require 'faraday/multipart'
require 'omniauth-orcid'
require 'oauth2'
require 'puma'
require 'require_all'
require 'nokogiri'
require 'uri'
require 'net/http'
require 'rack'
require 'rack/contrib'
require 'rack/protection'
require 'rack/tracker'
require 'redis'
require 'capitalize_names'
require 'csv'
require 'sidekiq'
require 'sidekiq/web'
require 'dwc_agent'
require 'i18n_data'
require 'colorize'
require 'ruby-progressbar'
require 'dwc_archive'
require 'zip'
require 'biodiversity'
require 'rss'
require 'sitemap_generator'
require 'wikidata'
require 'filemagic'
require 'sparql/client'
require 'oj'
require 'pluck_to_hash'
require 'pony'
require 'optparse'
require 'optparse/date'
require 'typhoeus'
require 'faraday/typhoeus'
require 'sort_alphabetical'

require_relative File.join(File.dirname(__FILE__), 'config', 'initialize')
require_relative File.join(File.dirname(__FILE__), 'config', 'initialize_state')

Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8

Zip.on_exists_proc = true
Zip.continue_on_exists_proc = true

Hashie.logger = Logger.new(nil)

OmniAuth.config.request_validation_phase = OmniAuth::AuthenticityTokenProtection.new(reaction: :drop_session)

require_all File.join(File.dirname(__FILE__), 'lib')
require_all File.join(File.dirname(__FILE__), 'helpers')
require_all File.join(File.dirname(__FILE__), 'routes')
require_all File.join(File.dirname(__FILE__), 'models')
