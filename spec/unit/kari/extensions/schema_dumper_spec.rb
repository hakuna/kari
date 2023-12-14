# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kari::Extensions::SchemaDumper do
  class MySchemaDumper
    prepend Kari::Extensions::SchemaDumper

    def initialize
      @connection = OpenStruct.new(schema_names: ["public", "acme", "foo"])
    end
  end

  let(:schema_dumper) { MySchemaDumper.new }

  describe "#schemas" do
    before { allow(Kari).to receive(:tenants).and_return(["acme"]) }

    it "dumps create_schema statements but excludes public and tenants" do
      stream = StringIO.new
      schema_dumper.schemas(stream)

      result = stream.string
      expect(result).not_to include("create_schema \"public\"")
      expect(result).not_to include("create_schema \"acme\"")
      expect(result).to include("create_schema \"foo\"")
    end
  end
end
