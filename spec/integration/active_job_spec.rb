# frozen_string_literal: true

require "spec_helper"

RSpec.describe "active job support" do
  include ActiveJob::TestHelper

  before do
    Kari.create("acme")
    Kari.create("umbrella-corp")
  end

  after do
    Kari.drop("acme")
    Kari.drop("umbrella-corp")
  end

  it "executes jobs in the proper tenant" do
    Kari.switch!("acme")
    acme_post = Post.create!(title: "ACME Post")

    Kari.switch!("umbrella-corp")
    umbrella_post = Post.create!(title: "Umbrella Post")

    expect do
      TouchJob.perform_later(acme_post)

      # ensure we 'injected' tenant
      enqueued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.first
      expect(enqueued_job["_tenant"]).to eq "acme"

      Kari.switch!("umbrella-corp")
      expect { perform_enqueued_jobs }.not_to change { Kari.current_tenant }
    end.to change { Kari.switch!("acme"); acme_post.reload.updated_at }
      .and not_change { Kari.switch!("umbrella-corp"); umbrella_post.reload.updated_at  }
  end

  it "supports rescue for case when tenant is no longer around (e.g. deleted in meantime)" do
    Kari.create("temp")
    Kari.switch!("temp")
    temp_post = Post.create!(title: "Umbrella Post")
    TouchJob.perform_later(temp_post)
    Kari.drop("temp")

    expect(Rails.logger).to receive(:error).with('All is lost!')
    expect { perform_enqueued_jobs }.not_to raise_error
  end
end
