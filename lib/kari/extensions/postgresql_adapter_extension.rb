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

        if Kari.current_schema.blank? && Kari.configuration.raise_if_schema_not_set
          raise Kari::SchemaNotSpecified, "Error: No schema set in current thread!"
        end

        if @__schema != Kari.current_schema
          # set first since schema search path setter does execute("SET search_path")...
          @__schema = Kari.current_schema

          # now set schema_search_path, which will set search_path
          self.schema_search_path = "\"#{Kari.current_schema}\""

          # clear cache since we have to swap schemas
          clear_query_cache
        end
      end
    end
  end
end
