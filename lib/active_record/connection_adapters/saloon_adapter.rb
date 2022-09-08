# frozen_string_literal: true

require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionHandling
    def saloon_connection(config)
      conn_params = config.symbolize_keys.compact

      # Map ActiveRecords param names to PGs.
      conn_params[:user] = conn_params.delete(:username) if conn_params[:username]
      conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]

      # Forward only valid config params to PG::Connection.connect.
      valid_conn_param_keys = PG::Connection.conndefaults_hash.keys + [:requiressl]
      conn_params.slice!(*valid_conn_param_keys)

      ConnectionAdapters::SaloonAdapter.new(
        ConnectionAdapters::SaloonAdapter.new_client(conn_params),
        logger,
        conn_params,
        config,
      )
    end
  end

  module ConnectionAdapters
    class SaloonAdapter < PostgreSQLAdapter
      class SchemaNotSpecified < StandardError; end

      def execute(*args)
        saloon_switch_to_schema do
          super
        end
      end

      def exec_query(sql, name = "SQL", binds = [], prepare: false, async: false, schema: nil)
        p [:schema, schema]
        saloon_switch_to_schema(schema) do
          super(sql, name, binds, prepare: prepare, async: async)
        end
      end

      private

      def saloon_switch_to_schema(schema = nil, &block)
        schema ||= saloon_determine_schema
        p "We are switching #{schema} #{Thread.current}"

        if @_saloon_connection_schema != schema
          # set first since schema search path setter does execute("SET search_path")...
          @_saloon_connection_schema = schema

          # now set schema_search_path, which will set search_path
          self.schema_search_path = schema

          # clear cache since we have to swap schemas
          clear_query_cache
        end

        block.call
      end

      def saloon_determine_schema
        current_schema = Saloon.configuration.current_schema
        current_schema.respond_to?(:call) ? current_schema.call  : current_schema
      end
    end
  end
end
