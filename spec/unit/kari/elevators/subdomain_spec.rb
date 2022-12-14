# frozen_string_literal: true

require "spec_helper"
require "kari/elevators/subdomain"

RSpec.describe Kari::Elevators::Subdomain do
  subject { -> { instance.call(env) } }

  let(:env) { Rack::MockRequest.env_for(uri, method: :get) }
  let(:uri) { "https://subdomain.kari.test" }
  let(:app) { ->(_env) { [200, {}, "success"] } }

  let(:instance) { described_class.new(app) }

  let(:tenant_exists) { true }

  before do
    allow(Kari).to receive(:process)
    allow(Kari).to receive(:exists?).and_return(tenant_exists)
  end

  shared_examples "a tenant switch" do |args|
    specify do
      expect(Kari).to receive(:process).with(args[:tenant])
      subject.call
    end
  end

  shared_examples "no tenant switch" do
    specify do
      expect(Kari).not_to receive(:process)
      subject.call
    end
  end

  context "with simple subdomain" do
    let(:uri) { "https://subdomain.kari.test" }

    it_behaves_like "a tenant switch", tenant: "subdomain"

    context "without tenant existing" do
      let(:tenant_exists) { false }

      it_behaves_like "no tenant switch"
    end
  end

  context "with multiple subdomains" do
    let(:uri) { "https://first.subdomain.here.kari.test" }

    it_behaves_like "a tenant switch", tenant: "first"

    context "without tenant existing" do
      let(:tenant_exists) { false }

      it_behaves_like "no tenant switch"
    end
  end

  context "with ip" do
    let(:uri) { "https://192.168.1.5" }

    it_behaves_like "no tenant switch"
  end

  describe "excluded subdomains" do
    before do
      described_class.excluded_subdomains = excluded_subdomains
    end

    let(:uri) { "https://app.kari.test" }

    context "without this subdomain excluded" do
      let(:excluded_subdomains) { ["test"] }

      it_behaves_like "a tenant switch", tenant: "app"

      context "without tenant existing" do
        let(:tenant_exists) { false }

        it_behaves_like "no tenant switch"
      end
    end

    context "with this subdomain excluded" do
      let(:excluded_subdomains) { %w[test app] }

      it_behaves_like "no tenant switch"
    end
  end
end
