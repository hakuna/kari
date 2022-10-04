# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kari::Extensions::PostgreSQLAdapterExtension do
  class MyAdapter
    prepend Kari::Extensions::PostgreSQLAdapterExtension

    attr_accessor :schema_search_path
    attr_reader :query_cache_cleared_at

    def execute(*args); end

    def exec_query(*args); end

    def clear_query_cache
      @query_cache_cleared_at = Time.zone.now
    end
  end

  let(:connection) { MyAdapter.new }

  before { allow(Kari).to receive(:schema_exists?).and_return(true) }

  shared_examples "not switching from schema" do |schema|
    specify do
      expect(connection).not_to receive(:clear_query_cache)
      expect { subject.call }.not_to change(connection, :schema_search_path).from("\"#{schema}\"")
    end
  end

  shared_examples "switching to schema" do |schema|
    specify do
      expect(connection).to receive(:clear_query_cache)
      expect { subject.call }.to change(connection, :schema_search_path).to("\"#{schema}\"")
    end
  end

  shared_examples "schema context switching" do
    before { allow(Kari).to receive(:current_tenant).and_return(current_tenant) }
    before { allow(Kari.configuration).to receive(:default_schema).and_return("mydefault") }

    context "tenant set" do
      let(:current_tenant) { "mytenant" }

      it_behaves_like "switching to schema", "mytenant"

      context "already set" do
        before { subject.call }

        it_behaves_like "not switching from schema", "mytenant"
      end
    end

    context "tenant not set" do
      let(:current_tenant) { nil }

      it_behaves_like "switching to schema", "mydefault"

      context "already set" do
        before { subject.call }

        it_behaves_like "not switching from schema", "mydefault"
      end
    end
  end

  describe "#execute" do
    subject { -> { connection.execute("SELECT * FROM posts") } }

    it_behaves_like "schema context switching"
  end

  describe "#exec_query" do
    subject { -> { connection.exec_query("SELECT * FROM posts", "SQL", [], prepare: false, tenant: "asynctenant") } }

    it_behaves_like "switching to schema", "asynctenant"
  end
end
