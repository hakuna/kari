# frozen_string_literal: true

module Kari
  module Extensions
    module PostgreSQLAdapterExtension71
      def cache_sql(*args)
        ensure_correct_schema_search_path!
        super
      end

      def internal_execute(*args, **kwargs)
        ensure_correct_schema_search_path!
        super
      end

      def internal_exec_query(*args, **kwargs)
        if tenant = kwargs.delete(:tenant)
          Kari.process(tenant) do
            ensure_correct_schema_search_path!
            super
          end
        else
          ensure_correct_schema_search_path!
          super
        end
      end

      def configure_connection
        # connection init or reset
        # make sure we (re-)set search_path later
        super
        @schema_search_path = nil
      end

      def schema_search_path=(schema_csv)
        if schema_csv
          method(:internal_execute).super_method.call("SET search_path TO #{schema_csv}", "SCHEMA")
          @schema_search_path = schema_csv
        end
      end

      def schema_search_path
        @schema_search_path ||= query_value("SHOW search_path", "SCHEMA")
      end

      private

      def ensure_correct_schema_search_path!
        search_path = Kari.current_tenant ? "\"#{Kari.current_tenant}\"" : Kari.configuration.default_schema

        if @schema_search_path != search_path
          # set correct schema search path
          self.schema_search_path = search_path

          # clear cache since we swapped schemas
          clear_query_cache
        end
      end
    end
  end
end
