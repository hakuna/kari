# frozen_string_literal: true

require_relative "kari/version"
require_relative "kari/railtie"
require_relative "kari/current"

module Kari
  class SchemaNotSpecified < StandardError; end

  class << self
    def configure(&block)
      block.call(configuration)
    end

    def connection
      ActiveRecord::Base.connection
    end

    def configuration
      Rails.application.config.kari
    end

    def set_global_schema!
      self.current_schema = configuration.global_schema
    end

    def ensure_schema_set!
      is_schema_set = current_schema.present? && current_schema != configuration.global_schema
      unless is_schema_set
        raise SchemaNotSpecified, "Schema is not set or set to global (current schema: '#{current_schema}')"
      end
    end

    def process(schema, &block)
      raise "Please supply block" unless block_given?

      old_schema = current_schema
      self.current_schema = schema
      value = block.call
      self.current_schema = old_schema
      value
    end

    def switch!(schema)
      self.current_schema = schema
    end

    def current_schema
      Kari::Current.schema
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
      seed_schema(schema) if Kari.configuration.seed_after_create
    end

    def drop_schema(schema)
      connection.drop_schema(schema)
    end

    def schemas
      configuration.schemas.respond_to?(:call) ? configuration.schemas.call : configuration.schemas
    end

    private

    def current_schema=(new_schema)
      Kari::Current.schema = new_schema
    end
  end
end
