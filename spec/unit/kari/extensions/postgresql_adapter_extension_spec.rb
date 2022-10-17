# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kari::Extensions::PostgreSQLAdapterExtension do
  class MyAdapter
    prepend Kari::Extensions::PostgreSQLAdapterExtension

    attr_accessor :schema_search_path
    attr_reader :query_cache_cleared_at

    def configure_connection
      # init/reset
    end

    def execute(*args)
      # execute
    end

    def exec_query(*args)
      # exec_query
    end

    def clear_query_cache
      @query_cache_cleared_at = Time.zone.now
    end

    def query_value(sql, name = nil)
      @schema_search_path if sql == "SHOW search_path"
    end
  end

  let(:connection) { MyAdapter.new }

  before { allow(Kari).to receive(:exists?).and_return(true) }

  shared_examples "not changing schema search path" do |search_path|
    specify do
      expect(connection).not_to receive(:clear_query_cache)
      expect { subject.call }.not_to change(connection, :schema_search_path).from(search_path)
    end
  end

  shared_examples "changing schema search path" do |search_path|
    specify do
      expect(connection).to receive(:clear_query_cache)
      expect { subject.call }.to change(connection, :schema_search_path).to(search_path)
    end
  end

  shared_examples "schema context switching" do
    before { allow(Kari).to receive(:current_tenant).and_return(current_tenant) }
    before { allow(Kari.configuration).to receive(:default_schema).and_return("mydefault") }

    context "with tenant set" do
      let(:current_tenant) { "mytenant" }

      it_behaves_like "changing schema search path", "\"mytenant\""

      context "with tenant already set" do
        before { subject.call }

        it_behaves_like "not changing schema search path", "\"mytenant\""
      end
    end

    context "with tenant not set" do
      let(:current_tenant) { nil }

      it_behaves_like "changing schema search path", "mydefault"

      context "with tenant already set" do
        before { subject.call }

        it_behaves_like "not changing schema search path", "mydefault"
      end
    end
  end

  describe "#execute" do
    subject { -> { connection.execute("SELECT * FROM posts") } }

    it_behaves_like "schema context switching"
  end

  describe "#exec_query" do
    subject { -> { connection.exec_query("SELECT * FROM posts", "SQL", [], prepare: false, tenant: "asynctenant") } }

    it_behaves_like "changing schema search path", "\"asynctenant\""
  end

  describe "#configure_connection" do
    subject { -> { connection.configure_connection } }

    it "resets the schema_search_path" do
      connection.schema_search_path = "test"
      expect { subject.call }.to change(connection, :schema_search_path).to(nil)
    end
  end
end
