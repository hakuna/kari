# frozen_string_literal: true

module Kari
  module Extensions
    module ActiveJobExtension

      def serialize
        super.merge("_tenant" => Kari.current_tenant)
      end

      def deserialize(job_data)
        super(job_data.except("_tenant"))
        @__tenant = job_data["_tenant"]
      end

      def perform_now
        if @__tenant
          Kari.process(@__tenant) { super }
        else
          super
        end
      rescue Kari::SchemaNotFound => exception
        # allow rescue_from
        rescue_with_handler(exception) || raise
      end

    end
  end
end
