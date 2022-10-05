# frozen_string_literal: true

require_relative "extensions/postgresql_adapter_extension"
require_relative "extensions/future_result_extension"
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
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(Kari::Extensions::PostgreSQLAdapterExtension)

      ActiveRecord::FutureResult.prepend(Kari::Extensions::FutureResultExtension) if Rails::VERSION::MAJOR >= 7

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
