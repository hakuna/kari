# frozen_string_literal: true

module Kari
  module Extensions
    module PostgreSQLAdapterExtension
      def initialize(*args)
        super
        @__primed = true # initialize does some housekeeping via execute (timezone etc., raise SchemaNotSpecified after connection is primed)
      end

      def execute(*args)
        ensure_schema_set
        super
      end

      def exec_query(*args, **kwargs)
        if schema = kwargs.delete(:schema)
          Kari.process(schema) do
            ensure_schema_set
            super
          end
        else
          ensure_schema_set
          super
        end
      end

      private

      def ensure_schema_set
        return unless @__primed # connection is still in initialization
        return if Rails.env.test?

        schema = Kari.current_schema.presence || Kari.configuration.global_schema

        if @__schema != schema
          # set first since schema search path setter does execute("SET search_path")...
          @__schema = schema

          # now set schema_search_path, which will set search_path
          self.schema_search_path = "\"#{schema}\""

          # clear cache since we have to swap schemas
          clear_query_cache
        end
      end
    end
  end
end
