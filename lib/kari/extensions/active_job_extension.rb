# frozen_string_literal: true

module Kari
  module Extensions
    module ActiveJobExtension
      def serialize
        super.merge(
          "_tenant" => Kari.current_tenant,
        )
      end

      def deserialize(job_data)
        if @_tenant = job_data["_tenant"]
          # we need to be in proper tenant for deserialization
          Kari.process(@_tenant) { super(job_data.except("_tenant")) }
        else
          super(job_data)
        end
      end

      def perform_now
        if @_tenant
          Kari.process(@_tenant) { super }
        else
          super
        end
      end
    end
  end
end
