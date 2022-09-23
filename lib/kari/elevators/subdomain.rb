# frozen_string_literal: true

module Kari
  module Elevators
    class Subdomain

      def self.excluded_subdomains
        @excluded_subdomains ||= []
      end

      def self.excluded_subdomains=(excluded_subdomains)
        @excluded_subdomains = excluded_subdomains
      end

      def initialize(app, environment = Rails.env)
        @app = app
        @environment = environment
      end

      def call(env)
        request = Rack::Request.new(env)
        subdomain = request.host.split('.').first.presence
        schema = if subdomain.present? && self.class.excluded_subdomains.exclude?(subdomain)
                   subdomain
                 else
                   Kari.configuration.global_schema
                 end

        Kari.process(schema) { @app.call(env) }
      end

    end
  end
end
