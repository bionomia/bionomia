# encoding: utf-8

module Sinatra
  module Bionomia
    module Model
      module Initialize

        def self.registered(app)

          app.set :database, Settings

          if app.settings.environment == :development
            ActiveRecord::Base.logger = Logger.new(STDOUT)
          end

          ActiveSupport::Inflector.inflections do |inflect|
            inflect.irregular 'taxon', 'taxa'
            inflect.irregular 'specimen', 'specimens'
            inflect.irregular 'person', 'people'
          end

          app.before { ActiveRecord::Base.verify_active_connections! if ActiveRecord::Base.respond_to?(:verify_active_connections!) }
          app.after { ActiveRecord::Base.clear_active_connections! }
        end

        def database=(spec)
          ActiveRecord::Base.establish_connection(
            adapter: spec.adapter,
            database: spec.database,
            host: spec.host,
            username: spec.username,
            password: spec.password,
            reconnect: spec.reconnect,
            pool: spec.pool,
            timeout: spec.timeout
          )
        end

        def database
          ActiveRecord::Base
        end

      end
    end
  end
end
