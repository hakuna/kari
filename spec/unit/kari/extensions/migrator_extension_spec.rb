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
end
