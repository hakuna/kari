# frozen_string_literal: true

require_relative "saloon/version"
require_relative "saloon/railtie"
require_relative "saloon/current"

# Saloon
module Saloon
  class << self
    def configure(&block)
      block.call(configuration)
    end

    def connection
      ActiveRecord::Base.connection
    end

    def each_schema(&block)
      schema_names.each(&block)
    end

    def configuration
      Rails.application.config.saloon
    end

    def current
      Saloon::Current
    end

    def process(schema, &block)
      raise "Please supply block" unless block_given?
      old_schema = current.schema
      block.call
      current.schema = old_schema
    end

    def switch!(schema)
      current.schema = schema
    end

    private

    def schema_names
      configuration.schema_names.respond_to?(:call) ? configuration.schema_names.call : configuration.schema_names
    end
  end
end
