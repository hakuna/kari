# frozen_string_literal: true

RSpec.describe Kari do
  it "has a version number" do
    expect(Kari::VERSION).not_to be nil
  end

  describe "#connection" do
    subject { described_class.connection }

    it { is_expected.to eq ActiveRecord::Base.connection }
  end

  describe "#ensure_tenant_set!" do
    subject { -> { described_class.ensure_tenant_set! } }

    before { allow(described_class).to receive(:current_tenant).and_return(current_tenant) }

    context "with tenant set" do
      let(:current_tenant) { "mytenant" }

      specify { expect { subject.call }.not_to raise_error }
    end

    context "without tenant et" do
      let(:current_tenant) { nil }

      specify { expect { subject.call }.to raise_error(described_class::TenantNotSet) }
    end
  end

  describe "#process" do
    subject { -> { described_class.process(tenant, &block) } }

    before { allow(described_class).to receive(:schema_exists?).and_return(schema_exists) }

    let(:block) do
      lambda do
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
      expect { subject.call }.not_to change(described_class, :current_tenant).from("prevtenant")
    end

    context "without schema of tenant existing" do
      let(:schema_exists) { false }

      specify { expect { subject.call }.to raise_error(described_class::SchemaNotFound) }
    end
  end

  describe "#switch!" do
    subject { -> { described_class.switch!("newtenant") } }

    before { allow(described_class).to receive(:schema_exists?).and_return(schema_exists) }

    context "with schema of tenant existing" do
      let(:schema_exists) { true }

      specify { expect { subject.call }.to change(described_class, :current_tenant).to("newtenant") }
    end

    context "without schema of tenant existing" do
      let(:schema_exists) { false }

      specify { expect { subject.call }.to raise_error(described_class::SchemaNotFound) }
    end
  end

  describe "#import_default_schema" do
    subject { -> { described_class.import_default_schema("mytenant") } }

    before { allow(described_class).to receive(:schema_exists?).and_return(true) }

    it "loads schema in tenant" do
      expect(described_class).to receive(:load).with(Rails.root.join("db/schema.rb")) do
        expect(described_class.current_tenant).to eq "mytenant"
      end

      subject.call
    end
  end

  describe "#seed" do
    subject { -> { described_class.seed("mytenant") } }

    before { allow(described_class).to receive(:schema_exists?).and_return(true) }

    it "loads seeds in tenant" do
      expect(described_class).to receive(:load).with(Rails.root.join("db/seeds.rb")) do
        expect(described_class.current_tenant).to eq "mytenant"
      end

      subject.call
    end
  end

  describe "#create" do
    subject { -> { described_class.create("mytenant") } }

    before { allow(described_class).to receive(:schema_exists?).and_return(schema_exists) }

    before do
      allow(described_class.connection).to receive(:create_schema)
      allow(described_class).to receive(:import_default_schema)
      allow(described_class).to receive(:seed)
    end

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

      describe "seed_after_create" do
        before { allow(described_class.configuration).to receive(:seed_after_create).and_return(seed_after_create) }

        context "with seeding enabled" do
          let(:seed_after_create) { true }

          it "loads seeds" do
            expect(described_class).to receive(:seed).with("mytenant")
            subject.call
          end
        end

        context "without seeding enabled" do
          let(:seed_after_create) { false }

          it "does not load seeds" do
            expect(described_class).not_to receive(:seed)
            subject.call
          end
        end
      end
    end

    context "without tenant existing" do
      let(:schema_exists) { true }

      specify { expect(subject.call).to eq false }

      it "does not attempt to create schema" do
        expect(described_class.connection).not_to receive(:create_schema)
        subject.call
      end
    end
  end

  describe "#drop" do
    subject { -> { described_class.drop("mytenant") } }

    before { allow(described_class).to receive(:schema_exists?).and_return(schema_exists) }
    before { allow(described_class.connection).to receive(:drop_schema) }

    context "without tenant existing" do
      let(:schema_exists) { true }

      specify { expect(subject.call).to eq true }

      it "drops schema" do
        expect(described_class.connection).to receive(:drop_schema).with("mytenant")
        subject.call
      end

      context "with current tenant set" do
        before { described_class.switch!(current_tenant) }
        after { described_class.switch!(nil) }

        context "with matches the one we drop" do
          let(:current_tenant) { "mytenant" }

          it "resets current tenant" do
            expect { subject.call }.to change(described_class, :current_tenant).to(nil)
          end
        end

        context "which does not match the one we drop" do
          let(:current_tenant) { "othertenant" }

          it "does not change current tenant" do
            expect { subject.call }.not_to change(described_class, :current_tenant)
          end
        end
      end
    end

    context "without tenant existing" do
      let(:schema_exists) { false }

      specify { expect(subject.call).to eq false }

      it "does not attempt drop schema" do
        expect(described_class.connection).not_to receive(:drop_schema)
        subject.call
      end
    end
  end

  describe "#tenants" do
    subject { described_class.tenants }

    before { allow(described_class.configuration).to receive(:tenants).and_return(tenants_config) }

    context "with configuration as static array" do
      let(:tenants_config) { %w[tenant1 tenant2 other-tenant] }

      it { is_expected.to eq %w[tenant1 tenant2 other-tenant] }
    end

    context "with configuration as proc" do
      let(:tenants_config) do
        lambda do
          [
            { id: 5, tenant: "tenantA" },
            { id: 22, tenant: "tenantX" }
          ].map { |instance| instance[:tenant] }
        end
      end

      it { is_expected.to eq %w[tenantA tenantX] }
    end
  end

  describe "extensions" do
    it "loaded extension for schema switching in postgresql connection adapter" do
      expect(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter).to include(Kari::Extensions::PostgreSQLAdapterExtension)
    end

    it "loaded extension for load_async tenant support through FutureResultExtension", if: Rails::VERSION::MAJOR >= 7 do
      expect(ActiveRecord::FutureResult).to include(Kari::Extensions::FutureResultExtension)
    end
  end
end
