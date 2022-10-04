# frozen_string_literal: true

RSpec.describe Kari do
  it "has a version number" do
    expect(Kari::VERSION).not_to be nil
  end

  describe "extensions" do
    it "postgresql adapter extension is loaded" do
      expect(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter).to include(Kari::Extensions::PostgreSQLAdapterExtension)
    end
  end

  describe "excluded models" do
    pending
  end
end
