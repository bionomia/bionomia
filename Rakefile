require 'rake'
require 'bundler/setup'
require 'rspec/core/rake_task'
require './application'

task :default => :test
task :test => :spec

task :environment do
  require_relative './application'
end

if !defined?(RSpec)
  puts "spec targets require RSpec"
else
  desc "Run all examples"
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = 'spec/**/*.rb'
  end
end

# usage: rake 'generate:migration[name_of_migration]'
# note the single quotes above, necessary in zsh
namespace :generate do
  task(:migration, :migration_name) do |t, args|
    timestamp = Time.now.gmtime.to_s[0..18].gsub(/[^\d]/, '')
    migration_name = args[:migration_name]
    file_name = "%s_%s.rb" % [timestamp, migration_name]
    class_name = migration_name.split("_").map {|w| w.capitalize}.join('')
    path = File.join(File.expand_path(File.dirname(__FILE__)), 'db', 'migrate', file_name)
    f = open(path, 'w')
    v = Gem.loaded_specs["activerecord"].version.to_s[0..2]
    content = "class #{class_name} < ActiveRecord::Migration[#{v}]
  def up
  end

  def down
  end
end
"
    f.write(content)
    puts "Generated migration %s" % path
    f.close
 end
end

namespace :elastic do
  namespace :create do
    task(:all) do
      INDICES = ["agent", "article", "dataset", "organization", "user", "taxon"]
      INDICES.each do |index_name|
        index = Object.const_get("Bionomia::Elastic#{index_name.capitalize}").new
        index.delete_index
        index.create_index
      end
    end
  end
end

namespace :db do

  desc "Migrate the database"
  task(:migrate => :environment) do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    ActiveRecord::MigrationContext.new('db/migrate').migrate
  end

  namespace :drop do
    task(:all) do
      if ['0.0.0.0', '127.0.0.1', 'localhost'].include?(Settings[:host].strip)
        Settings.add_source!({
          ssl_mode: Trilogy::SSL_PREFERRED_NOVERIFY,
          tls_min_version: Trilogy::TLS_VERSION_12
        })
        Settings.reload!
        database = Settings.delete(:database)
        ActiveRecord::Base.establish_connection(Settings.to_hash)
        ActiveRecord::Base.connection.execute("drop database if exists #{database}")
      end
    end
  end

  namespace :create do
    task(:all) do
      if ['0.0.0.0', '127.0.0.1', 'localhost'].include?(Settings[:host].strip)
        Settings.add_source!({
          ssl_mode: Trilogy::SSL_PREFERRED_NOVERIFY,
          tls_min_version: Trilogy::TLS_VERSION_12
        })
        Settings.reload!
        database = Settings.delete_field(:database)
        ActiveRecord::Base.establish_connection(Settings.to_hash)
        ActiveRecord::Base.connection.execute("create database if not exists #{database}")
      end
    end
  end

  namespace :schema do
    task(:load) do
      if ['0.0.0.0', '127.0.0.1', 'localhost'].include?(Settings[:host].strip)
        script = open(File.join(File.expand_path(File.dirname(__FILE__)), 'db', 'bionomia.sql')).read

        # this needs to match the delimiter of your queries
        STATEMENT_SEPARATOR = ";\n"

        ActiveRecord::Base.establish_connection(Settings.to_hash)
        script.split(STATEMENT_SEPARATOR).each do |stmt|
          ActiveRecord::Base.connection.execute(stmt)
        end

      end
    end
  end

  namespace :seed do
    statements = [
      "INSERT INTO key_values(k,v) VALUES ('off_datetime', NULL), ('off_duration', NULL), ('online_when', NULL)"
    ]
    ActiveRecord::Base.establish_connection(Settings.to_hash)
    statements.each do |stmt|
      ActiveRecord::Base.connection.execute(stmt)
    end
  end

end
