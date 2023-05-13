# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kari::Extensions::MigratorExtension do
  class MyMigrator
    prepend Kari::Extensions::MigratorExtension

    def generate_migrator_advisory_lock_id
      Zlib.crc32("database")
    end
  end

  let(:migrator) { MyMigrator.new }

  describe "#with_advisory_lock_connection" do
    it "only creates one pool, so advisory lock can reuse connections, leading to subsequent faster migrations" do
      connections = []

      5.times do
        migrator.with_advisory_lock_connection do |connection|
          connections << connection
        end
      end

      expect(connections.uniq.count).to eq(1)
    end
  end

  describe "#generate_migrator_advisory_lock_id" do
    it "creates a unique lock id for each tenant schema" do
      allow(Kari).to receive(:current_tenant).and_return('acme')
      lock_id1 = migrator.generate_migrator_advisory_lock_id

      allow(Kari).to receive(:current_tenant).and_return('umbrella-corp')
      lock_id2 = migrator.generate_migrator_advisory_lock_id

      expect(lock_id1).not_to eq(lock_id2)
    end
  end
end
