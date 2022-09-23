# frozen_string_literal: true

module Kari
  module Extensions
    module FutureResultExtension
      class SchemaNotSpecified < StandardError; end

      # Add schema to kwargs when we schedule (load_async support)
      # Async exec be invoked with schema keyword arg, which
      # is handled by PostgreSQLAdapterExtension
      def schedule!(session)
        @kwargs[:schema] = Kari.current_schema
        super
      end
    end
  end
end
