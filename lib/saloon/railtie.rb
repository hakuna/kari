# frozen_string_literal: true

module Saloon
  class Railtie < Rails::Railtie
    config.saloon = ActiveSupport::OrderedOptions.new

    config.saloon.global_models = []
    config.saloon.global_schema = 'public'
    config.saloon.schema_names = []

    config.to_prepare do
      # monkey patch
      module ::ActiveRecord
        class FutureResult
          def schedule!(session)
            @kwargs[:schema] = Current.tenant

            @session = session
            @pool.schedule_query(self)
          end
        end
      end

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
