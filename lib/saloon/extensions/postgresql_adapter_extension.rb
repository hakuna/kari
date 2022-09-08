module Saloon
  module Extensions

    module PostgreSQLAdapterExtension
      class SchemaNotSpecified < StandardError; end

      def execute(*args)
        within_saloon_schema do
          super
        end
      end

      def exec_query(*args, **kwargs)
        within_saloon_schema kwargs.delete(:schema) do
          super(*args, **kwargs)
        end
      end

      private

      def within_saloon_schema(schema = nil, &block)
        schema ||= Saloon.current.schema
        raise SchemaNotSpecified if schema.blank?

        if @_saloon_conn_schema != schema
          puts "Switch from #{@_saloon_conn_schema} to #{schema}"

          # set first since schema search path setter does execute("SET search_path")...
          @_saloon_conn_schema = schema

          # now set schema_search_path, which will set search_path
          self.schema_search_path = schema

          # clear cache since we have to swap schemas
          clear_query_cache
        end

        block.call
      end
    end

  end
end
