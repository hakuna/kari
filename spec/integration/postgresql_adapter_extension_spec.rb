# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Postgresql adapter extension integration" do
  before do
    Kari.create("tenant1")
    Kari.create("tenant2")

    Kari.switch!("tenant1")
    Post.create!(title: "Tenant1: Foo")
    Post.create!(title: "Tenant1: Bar")

    Kari.switch!("tenant2")
    Post.create!(title: "Tenant2: Hello World")
  end

  after do
    Kari.drop("tenant1")
    Kari.drop("tenant2")
  end

  let(:connection) { ActiveRecord::Base.connection }

  describe "#execute" do
    specify do
      Kari.switch! "tenant1"
      result = connection.execute("SELECT * FROM posts")
      expect(result.cmd_tuples).to eq 2
      expect(result).to be_all { |row| row["title"].include?("Tenant1") }

      Kari.switch! "tenant2"
      result = connection.execute("SELECT * FROM posts")
      expect(result.cmd_tuples).to eq 1
      expect(result).to be_all { |row| row["title"].include?("Tenant2") }
    end
  end

  describe "#exec_query" do
    specify do
      Kari.switch! "tenant1"
      result = connection.exec_query("SELECT * FROM posts", "SQL", [], prepare: false)
      expect(result.rows.count).to eq 2

      Kari.switch! "tenant2"
      result = connection.exec_query("SELECT * FROM posts", "SQL", [], prepare: false)
      expect(result.rows.count).to eq 1
    end

    describe "support for tenant: keyword (future result)" do
      context "Rails < 7.1", if: Rails::VERSION::STRING < "7.1" do
        specify do
          Kari.switch! "tenant1"
          result = connection.exec_query("SELECT * FROM posts", "SQL", [], prepare: false)
          expect(result.rows.count).to eq 2
          result = connection.exec_query("SELECT * FROM posts", "SQL", [], prepare: false, tenant: "tenant2")
          expect(result.rows.count).to eq 1
          result = connection.exec_query("SELECT * FROM posts", "SQL", [], prepare: false)
          expect(result.rows.count).to eq 2
        end
      end

      context "Rails >= 7.1", if: Rails::VERSION::STRING >= "7.1" do
        specify do
          Kari.switch! "tenant1"
          result = connection.internal_exec_query("SELECT * FROM posts", "SQL", [], prepare: false)
          expect(result.rows.count).to eq 2
          result = connection.internal_exec_query("SELECT * FROM posts", "SQL", [], prepare: false, tenant: "tenant2")
          expect(result.rows.count).to eq 1
          result = connection.internal_exec_query("SELECT * FROM posts", "SQL", [], prepare: false)
          expect(result.rows.count).to eq 2
        end
      end
    end
  end

  context "with connection reset" do
    it "keeps the schema search path" do
      Kari.switch! "tenant1"

      result = connection.execute("SELECT * FROM posts")
      expect(result.cmd_tuples).to eq 2

      # connection reset resets schema
      connection.reset!

      result = connection.execute("SELECT * FROM posts")
      expect(result.cmd_tuples).to eq 2
    end
  end

  context "with outside mingling" do
    it "keeps the schema search path" do
      Kari.switch! "tenant1"

      result = connection.execute("SELECT * FROM posts")
      expect(result.cmd_tuples).to eq 2
      expect(result).to be_all { |row| row["title"].include?("Tenant1") }

      connection.schema_search_path = "\"tenant2\""

      result = connection.execute("SELECT * FROM posts")
      expect(result.cmd_tuples).to eq 2
      expect(result).to be_all { |row| row["title"].include?("Tenant1") }
    end
  end


end
