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

  describe "#connection" do
    subject { described_class.connection }

    it { is_expected.to eq ActiveRecord::Base.connection }
  end

  describe "#ensure_tenant_set!" do
    before { allow(described_class).to receive(:current_tenant).and_return(current_tenant) }

    subject { -> { described_class.ensure_tenant_set! } }

    context "tenant set" do
      let(:current_tenant) { "mytenant" }

      specify { expect { subject.call }.not_to raise_error }
    end

    context "tenant NOT set" do
      let(:current_tenant) { nil }

      specify { expect { subject.call }.to raise_error(described_class::TenantNotSet) }
    end
  end

  describe "#process" do
    before { allow(described_class).to receive(:schema_exists?).and_return(schema_exists) }

    subject { -> { described_class.process(tenant, &block) } }

    let(:block) do
      -> do
        expect(described_class.current_tenant).to eq(tenant)
        1234
      end
    end

    let(:tenant) { "acme" }
    let(:schema_exists) { true }

    it "returns returned value of block" do
      expect(subject.call).to eq 1234
    end

    it "keeps tenant" do
      described_class.switch!("prevtenant")
      expect { subject.call }.not_to change { described_class.current_tenant }.from("prevtenant")
    end

    context "schema of tenant does not exist" do
      let(:schema_exists) { false }

      specify { expect { subject.call }.to raise_error(described_class::SchemaNotFound) }
    end
  end

  describe "#switch!" do
    before { allow(described_class).to receive(:schema_exists?).and_return(schema_exists) }

    subject { -> { described_class.switch!("newtenant") } }

    context "schema exists" do
      let(:schema_exists) { true }

      specify { expect { subject.call }.to change { described_class.current_tenant }.to("newtenant") }
    end

    context "schema does not exist" do
      let(:schema_exists) { false }

      specify { expect { subject.call }.to raise_error(described_class::SchemaNotFound) }
    end
  end

  describe "#import_default_schema" do
    before { allow(described_class).to receive(:schema_exists?).and_return(true) }

    subject { -> { described_class.import_default_schema("mytenant") } }

    it "loads schema in tenant" do
      expect(described_class).to receive(:load).with(Rails.root.join("db/schema.rb")) do
        expect(described_class.current_tenant).to eq "mytenant"
      end

      subject.call
    end
  end

  describe "#seed" do
    before { allow(described_class).to receive(:schema_exists?).and_return(true) }

    subject { -> { described_class.seed("mytenant") } }

    it "loads seeds in tenant" do
      expect(described_class).to receive(:load).with(Rails.root.join("db/seeds.rb")) do
        expect(described_class.current_tenant).to eq "mytenant"
      end

      subject.call
    end
  end

  describe "#create" do
    before { allow(described_class).to receive(:schema_exists?).and_return(schema_exists) }

    before do
      allow(described_class.connection).to receive(:create_schema)
      allow(described_class).to receive(:import_default_schema)
      allow(described_class).to receive(:seed)
    end

    subject { -> { described_class.create("mytenant") } }

    context "tenant does not exist yet" do
      let(:schema_exists) { false }

      specify { expect(subject.call).to eq true }

      it "creates schema" do
        expect(described_class.connection).to receive(:create_schema).with("mytenant")
        subject.call
      end

      it "imports default schema" do
        expect(described_class).to receive(:import_default_schema).with("mytenant")
        subject.call
      end

      context "seed_after_create" do
        before { allow(described_class.configuration).to receive(:seed_after_create).and_return(seed_after_create) }

        context "enabled" do
          let(:seed_after_create) { true }

          it "loads seeds" do
            expect(described_class).to receive(:seed).with("mytenant")
            subject.call
          end
        end

        context "disabled" do
          let(:seed_after_create) { false }

          it "does not load seeds" do
            expect(described_class).not_to receive(:seed)
            subject.call
          end
        end
      end
    end

    context "tenant does already exist" do
      let(:schema_exists) { true }

      specify { expect(subject.call).to eq false }

      it "does not attempt to create schema" do
        expect(described_class.connection).not_to receive(:create_schema)
        subject.call
      end
    end
  end

  describe "#drop" do
    before { allow(described_class).to receive(:schema_exists?).and_return(schema_exists) }
    before { allow(described_class.connection).to receive(:drop_schema) }

    subject { -> { described_class.drop("mytenant") } }

    context "tenant does exist" do
      let(:schema_exists) { true }

      specify { expect(subject.call).to eq true }

      it "drops schema" do
        expect(described_class.connection).to receive(:drop_schema).with("mytenant")
        subject.call
      end
    end

    context "tenant does not exist" do
      let(:schema_exists) { false }

      specify { expect(subject.call).to eq false }

      it "does not attempt drop schema" do
        expect(described_class.connection).not_to receive(:drop_schema)
        subject.call
      end
    end
  end

  describe "#tenants" do
    before { allow(described_class.configuration).to receive(:tenants).and_return(tenants_config) }

    subject {  described_class.tenants }

    context "configured as static array" do
      let(:tenants_config) { %w[tenant1 tenant2 other-tenant] }

      it { is_expected.to eq %w[tenant1 tenant2 other-tenant] }
    end

    context "configured as proc" do
      let(:tenants_config) do
        -> do
          [
            { id: 5, tenant: "tenantA" },
            { id: 22, tenant: "tenantX" },
          ].map { |instance| instance[:tenant] }
        end
      end

      it { is_expected.to eq %w[tenantA tenantX] }
    end

  end

  describe "excluded models" do
    pending
  end
end
