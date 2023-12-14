# frozen_string_literal: true

require "spec_helper"

RSpec.describe "schema dumper", if: Rails::VERSION::STRING >= "7.1" do
  before do
    self.use_transactional_tests = false

    Kari.create("acme")
    Kari.create("umbrella-corp")

    allow(Kari).to receive(:tenants).and_return(["acme"])
  end

  after do
    Kari.drop("acme")
    Kari.drop("umbrella-corp")
  end

  it "dumps only non-tenant schemas" do
    tempfile = Tempfile.new("schema.rb")
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, tempfile)
    tempfile.rewind

    schema = tempfile.read
    expect(schema).to include("create_schema \"umbrella-corp\"")
    expect(schema).not_to include("create_schema \"acme\"") # tenant schema excluded
  end
end
