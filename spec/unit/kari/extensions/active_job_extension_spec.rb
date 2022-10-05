# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kari::Extensions::ActiveJobExtension do
  class MyActiveJob
    prepend Kari::Extensions::ActiveJobExtension

    def serialize
      {
        "enqueued_at" => Time.current,
      }
    end

    def deserialize(job_data)
    end

    def perform_now
    end
  end

  let(:job) { MyActiveJob .new }

  before { allow(Kari).to receive(:current_tenant).and_return("mytenant") }

  describe 'serialization' do
    subject { -> { job.serialize } }

    it 'serializes w/ current tenant' do
      expect(subject.call).to match(
        "enqueued_at" => anything,
        "_tenant" => "mytenant",
      )
    end
  end

  context "deserialize" do
    subject { -> { job.deserialize(job_data) } }

    let(:job_data) { { "job_class" => "MyActiveJob", "_tenant" => tenant }.compact }

    context "tenant in job data" do
      let(:tenant) { "acme" }

      specify do
        expect(Kari).to receive(:process).with("acme")

        subject.call
      end
    end

    context "no tenant in job data" do
      let(:tenant) { nil }

      specify do
        expect(Kari).not_to receive(:process)

        subject.call
      end
    end
  end

  context "perform_now" do
    subject { -> { job.perform_now } }

    let(:job_data) { { "job_class" => "MyActiveJob", "_tenant" => tenant }.compact }

    before { allow(Kari).to receive(:schema_exists?).and_return(true) }
    before { job.deserialize(job_data) }

    context "tenant in job data " do
      let(:tenant) { "acme" }

      specify do
        expect(Kari).to receive(:process).with("acme")

        subject.call
      end
    end

    context "no tenant in job data" do
      let(:tenant) { nil }

      specify do
        expect(Kari).not_to receive(:process)

        subject.call
      end
    end
  end
end
