# frozen_string_literal: true

require "spec_helper"

RSpec.describe "improved migration performance" do
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

  it "optimizes advisory locks by re-using previously created pool instead of recreating a new one for each migration" do
    num_pools_created = 0
    allow_any_instance_of(ActiveRecord::ConnectionAdapters::ConnectionHandler).to receive(:establish_connection).and_wrap_original do |method, *args|
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

  it "improves performance by including tenant schema in the lock id, so the advisory locks down the tenant schema" do
    lock_ids = []

    allow_any_instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter).to receive(:get_advisory_lock).and_wrap_original do |method, lock_id|
      lock_ids << lock_id
      method.call(lock_id)
    end

    [nil, 'acme', 'acme', 'umbrella-corp'].each do |tenant|
      Kari.switch! tenant
      ActiveRecord::Migrator.new(:up, [], @schema_migration).migrate
    end

    expect(lock_ids.uniq.count).to eq 3
  end
end
