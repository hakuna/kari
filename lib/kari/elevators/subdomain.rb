# frozen_string_literal: true

module Kari
  module Elevators
    class Subdomain
      def self.excluded_subdomains
        @excluded_subdomains ||= []
      end

      class << self
        attr_writer :excluded_subdomains
      end

      def initialize(app, environment = Rails.env)
        @app = app
        @environment = environment
      end

      def call(env)
        request = Rack::Request.new(env)
        tenant = nil

        unless ip_host?(request.host)
          subdomain = request.host.split(".").first.presence
          tenant = subdomain if subdomain.present? && self.class.excluded_subdomains.exclude?(subdomain)
        end

        if tenant && Kari.exists?(tenant)
          Kari.process(tenant) { @app.call(env) }
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
