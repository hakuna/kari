# frozen_string_literal: true

module Kari
  module Extensions

    module MigratorExtension
      extend ActiveSupport::Concern

      prepended do
        def self.advisory_lock_connection_pool
          # ActiveSupport::IsolatedExecutionState is only available in Rails 7+
          state = defined?(ActiveSupport::IsolatedExecutionState) ?
            ActiveSupport::IsolatedExecutionState : Thread.current

          state[:advisory_lock_connection_pool] ||= ActiveRecord::ConnectionAdapters::ConnectionHandler
            .new.establish_connection(ActiveRecord::Base.connection_db_config)
        end
      end

      # The original method recreates a connection pool for each migration
      # Slowing down the migration process considerably
      def with_advisory_lock_connection
        self.class.advisory_lock_connection_pool.with_connection { |connection| yield(connection) }
      end

    end

  end
end
