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
        schema = nil

        unless ip_host?(request.host)
          subdomain = request.host.split('.').first.presence
          if subdomain.present? && self.class.excluded_subdomains.exclude?(subdomain)
            schema = subdomain
          end
        end

        if schema
          Kari.process(schema) { @app.call(env) }
        else
          @app.call(env)
        end
      end

      private

      def ip_host?(host)
        !/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/.match(host).nil?
      end
    end
  end
end
