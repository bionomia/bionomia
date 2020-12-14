require 'bundler'
require 'ostruct'
require 'logger'
require 'mysql2'
require 'active_record'
require 'active_record_union'
require 'activerecord-import'
require 'active_support/all'
require 'action_view'
require 'charlock_holmes'
require 'counter_culture'
require 'rest_client'
require 'json'
require 'sanitize'
require 'htmlentities'
require 'i18n'
require 'tilt/haml'
require 'sinatra/base'
require 'sinatra/content_for'
require 'sinatra/cacher'
require 'sinatra/flash'
require 'sinatra/outputbuffer'
require 'sinatra/support/i18nsupport'
require 'config'
require 'yaml'
require 'namae'
require 'elasticsearch'
require 'pagy'
require 'pagy/extras/arel'
require 'pagy/extras/array'
require 'pagy/extras/bootstrap'
require 'pagy/extras/countless'
require 'pagy/extras/elasticsearch_rails'
require 'pagy/extras/i18n'
require 'pagy/extras/metadata'
require 'parallel'
require 'chronic'
require 'omniauth-orcid'
require 'thin'
require 'oauth2'
require 'require_all'
require 'nokogiri'
require 'uri'
require 'net/http'
require 'rack'
require 'rack/contrib'
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
require 'twitter'
require 'sucker_punch'
require 'optparse'

require_relative File.join(File.dirname(__FILE__), 'lib', 'omniauth_authenticity_checker')
require_relative File.join(File.dirname(__FILE__), 'config', 'initialize')

Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8

Zip.on_exists_proc = true
Zip.continue_on_exists_proc = true

Hashie.logger = Logger.new(nil)

OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.before_request_phase = OmniauthAuthenticityChecker.new(reaction: :drop_session)

require_all File.join(File.dirname(__FILE__), 'lib')
require_all File.join(File.dirname(__FILE__), 'helpers')
require_all File.join(File.dirname(__FILE__), 'controllers')
require_all File.join(File.dirname(__FILE__), 'models')
