# frozen_string_literal: true

require "spec_helper"

RSpec.describe "improved migration performance", if: Rails::VERSION::STRING < "7.1" do
  before do
    self.use_transactional_tests = false

    Kari.create("acme")
    Kari.create("umbrella-corp")
  end

  after do
    Kari.drop("acme")
    Kari.drop("umbrella-corp")
  end

  before do
    @schema_migration = ActiveRecord::Base.connection.schema_migration
  end

  it "optimizes advisory locks by re-using previously created pool" do
    num_pools_created = 0
    allow_any_instance_of(ActiveRecord::ConnectionAdapters::ConnectionHandler)
      .to receive(:establish_connection).and_wrap_original do |method, *args|

      num_pools_created += 1
      method.call(*args)
    end

    # pid = fork do
    3.times do
      migrator = ActiveRecord::Migrator.new(:up, [], @schema_migration)
      expect(migrator).to receive(:with_advisory_lock).and_call_original
      migrator.migrate
    end

    expect(num_pools_created).to eq(1)
  end
end
