# frozen_string_literal: true

module Kari
  module Extensions
    module PostgreSQLAdapterExtension
      def initialize(*args)
        super
        @__initialized = true # initialize does some housekeeping via execute (timezone etc., raise SchemaNotSpecified after connection is primed)
      end

      def execute(*args)
        within_schema_context { super }
      end

      def exec_query(*args, **kwargs)
        if tenant = kwargs.delete(:tenant)
          Kari.process(tenant) { within_schema_context { super } }
        else
          within_schema_context { super }
        end
      end

      private

      def within_schema_context
        return yield unless @__initialized # connection is still in initialization

        schema = Kari.current_tenant || Kari.configuration.default_schema

        if @__schema != schema
          # set first since schema search path setter does execute("SET search_path")...
          @__schema = schema

          # now set schema_search_path, which will set search_path
          self.schema_search_path = "\"#{schema}\""

          # clear cache since we have to swap schemas
          clear_query_cache
        end

        yield
      end
    end
  end
end
