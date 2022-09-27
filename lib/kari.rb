# frozen_string_literal: true

require_relative "kari/version"
require_relative "kari/railtie"
require_relative "kari/current"

module Kari
  class SchemaNotFound < StandardError; end
  class SchemaNotSet < StandardError; end

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

    def ensure_schema_set!
      is_schema_set = current_schema.present? && current_schema != configuration.global_schema
      unless is_schema_set
        raise SchemaNotSet, "Schema is not set or set to global (current schema: '#{current_schema}')"
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
      return false if schema_exists?(schema)

      connection.create_schema(schema)
      import_global_schema(schema)
      seed_schema(schema) if Kari.configuration.seed_after_create
      true
    end

    def drop_schema(schema)
      return false unless schema_exists?(schema)

      connection.drop_schema(schema)
      true
    end

    def schemas
      configuration.schemas.respond_to?(:call) ? configuration.schemas.call : configuration.schemas
    end

    private

    def current_schema=(new_schema)
      if new_schema == configuration.global_schema
        new_schema = nil
      end

      if new_schema.nil?
        Kari::Current.schema = nil
      else
        raise SchemaNotFound, "Schema '#{new_schema}' does not exist" unless schema_exists?(new_schema)
        Kari::Current.schema = new_schema
      end
    end
  end
end
