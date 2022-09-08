# frozen_string_literal: true

require_relative "extensions/postgresql_adapter_extension"
require_relative "extensions/future_result_extension"

require "active_record/connection_adapters/postgresql_adapter"

module Saloon
  class Railtie < Rails::Railtie
    config.saloon = ActiveSupport::OrderedOptions.new

    config.saloon.global_models = []
    config.saloon.global_schema = 'public'
    config.saloon.schema_names = []
    config.saloon.raise_if_schema_not_set = true

    config.to_prepare do
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(Saloon::Extensions::PostgreSQLAdapterExtension)
      ActiveRecord::FutureResult.prepend(Saloon::Extensions::FutureResultExtension)

      # explicitly direct global models to default schema
      Saloon.configuration.global_models.each do |global_model|
        klass = global_model.constantize

        table_name = klass.table_name.split('.', 2).last
        klass.table_name = "#{Saloon.configuration.global_schema}.#{table_name}"
      end
    end

    rake_tasks do
      load 'tasks/saloon.rake'
    end
  end
end
