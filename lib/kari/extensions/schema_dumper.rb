
# frozen_string_literal: true

module Kari
  module Extensions

    module SchemaDumper
      extend ActiveSupport::Concern

      def schemas(stream)
        # exclude tenants from list of create_schema statements
        schema_names = @connection.schema_names - ["public"] - Kari.tenants

        if schema_names.any?
          schema_names.sort.each do |name|
            stream.puts "  create_schema #{name.inspect}"
          end
          stream.puts
        end
      end

    end

  end
end
