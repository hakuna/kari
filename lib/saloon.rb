# frozen_string_literal: true

require_relative "saloon/version"
require_relative "saloon/railtie"
require_relative "saloon/current"

# Saloon
module Saloon
  class SchemaNotSpecified < StandardError; end

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

    def set_global_schema!
      self.current_schema = configuration.global_schema
    end

    def ensure_schema_set!
      is_schema_set = self.current_schema.present? && self.current_schema != configuration.global_schema
      raise SchemaNotSpecified.new("Schema is not set or set to global (current schema: '#{self.current_schema}')") unless is_schema_set
    end

    def process(schema, &block)
      raise "Please supply block" unless block_given?
      old_schema = current_schema
      self.current_schema = schema
      value = block.call
      self.current_schema = old_schema
      value
    end

    def current_schema=(new_schema)
      Saloon::Current.schema = new_schema
    end

    def current_schema
      Saloon::Current.schema
    end

    def schema_exists?(schema)
      connection.schema_exists?(schema)
    end

    def import_global_schema(schema)
      process(schema) do
        load Rails.root.join("db/schema.rb")
      end
    end

    def seed_schema(schema)
      process(schema) do
        load Rails.root.join("db/seeds.rb")
      end
    end

    def create_schema(schema)
      connection.create_schema(schema)
      import_global_schema(schema)
      seed_schema(schema) if Saloon.configuration.seed_after_create
    end

    def drop_schema(schema)
      connection.drop_schema(schema)
    end

    private

    def schema_names
      configuration.schema_names.respond_to?(:call) ? configuration.schema_names.call : configuration.schema_names
    end
  end
end
