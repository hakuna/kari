# frozen_string_literal: true

require_relative "extensions/postgresql_adapter_extension61"
require_relative "extensions/postgresql_adapter_extension71"

require_relative "extensions/future_result_extension"
require_relative "extensions/migrator_extension"
require_relative "extensions/schema_dumper"
require_relative "extensions/active_job_extension"

require "active_record/connection_adapters/postgresql_adapter"

module Kari
  class Railtie < Rails::Railtie
    config.kari = ActiveSupport::OrderedOptions.new

    config.kari.excluded_models = []
    config.kari.default_schema = "public"
    config.kari.tenants = []
    config.kari.seed_after_create = false

    config.to_prepare do
      if Rails::VERSION::STRING >= "7.1"
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(Kari::Extensions::PostgreSQLAdapterExtension71)
      else
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(Kari::Extensions::PostgreSQLAdapterExtension61)
      end

      if Rails::VERSION::STRING < "7.1"
        ActiveRecord::Migrator.prepend(Kari::Extensions::MigratorExtension)
      end

      if Rails::VERSION::STRING >= "7.0"
        ActiveRecord::FutureResult.prepend(Kari::Extensions::FutureResultExtension)
      end

      if Rails::VERSION::STRING >= "7.1"
        ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper.prepend(Kari::Extensions::SchemaDumper)
      end

      ActiveJob::Base.prepend(Kari::Extensions::ActiveJobExtension) if defined?(ActiveJob::Base)

      # explicitly direct excluded models to default schema
      Kari.configuration.excluded_models.each do |excluded_model|
        klass = excluded_model.to_s.constantize

        table_name = klass.table_name.split(".", 2).last
        klass.table_name = "#{Kari.configuration.default_schema}.#{table_name}"
      end
    end

    rake_tasks do
      load "tasks/kari.rake"
    end
  end
end
