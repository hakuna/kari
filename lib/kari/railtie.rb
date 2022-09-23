# frozen_string_literal: true

require_relative "extensions/postgresql_adapter_extension"
require_relative "extensions/future_result_extension"

require "active_record/connection_adapters/postgresql_adapter"

module Kari
  class Railtie < Rails::Railtie
    config.kari = ActiveSupport::OrderedOptions.new

    config.kari.global_models = []
    config.kari.global_schema = "public"
    config.kari.schema_names = []
    config.kari.raise_if_schema_not_set = true
    config.kari.seed_after_create = false

    config.to_prepare do
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(Kari::Extensions::PostgreSQLAdapterExtension)

      if defined?(ActiveRecord::FutureResult)
        ActiveRecord::FutureResult.prepend(Kari::Extensions::FutureResultExtension)
      end

      # tell sidekiq to serialize kari data for background jobs (if sidekiq is around)
      begin
        require "sidekiq/middleware/current_attributes"
        Sidekiq::CurrentAttributes.persist(Kari::Current)
      rescue LoadError
      end

      # explicitly direct global models to default schema
      Kari.configuration.global_models.each do |global_model|
        klass = global_model.constantize

        table_name = klass.table_name.split(".", 2).last
        klass.table_name = "#{Kari.configuration.global_schema}.#{table_name}"
      end

      # set global schema as initial schema for console etc.
      Kari.set_global_schema!
    end

    rake_tasks do
      load "tasks/kari.rake"
    end
  end
end
