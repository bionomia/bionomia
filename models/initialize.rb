# encoding: utf-8

module Sinatra
  module Bionomia
    module Model
      module Initialize

        def self.registered(app)
          config = {
            adapter: Settings.adapter,
            database: Settings.database,
            host: Settings.host,
            username: Settings.username,
            password: Settings.password,
            ssl: Settings.ssl,
            ssl_mode: Trilogy::SSL_PREFERRED_NOVERIFY,
            tls_min_version: Trilogy::TLS_VERSION_12,
            pool: Settings.pool,
            timeout: Settings.timeout
          }

          hash = {}
          hash[app.settings.environment] = config
          hash[:default_env] = config
          db_configs = ActiveRecord::DatabaseConfigurations.new hash

          ActiveRecord::Base.configurations = db_configs
          ActiveRecord::Base.establish_connection

          if app.settings.environment == :development
            ActiveRecord::Base.logger = Logger.new(STDOUT)
          end

          ActiveSupport::Inflector.inflections do |inflect|
            inflect.irregular 'taxon', 'taxa'
            inflect.irregular 'specimen', 'specimens'
            inflect.irregular 'person', 'people'
          end

          app.after { ActiveRecord::Base.connection_handler.clear_active_connections!(:all) }
        end

      end
    end
  end
end
