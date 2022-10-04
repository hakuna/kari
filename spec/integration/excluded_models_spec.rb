# frozen_string_literal: true

require "spec_helper"

RSpec.describe "excluded models" do
  before do
    Kari.create("acme")
    Kari.create("umbrella-corp")

    Kari.switch!("acme")
    Post.create!(title: "ACME Post")
  end

  after do
    Kari.drop("acme")
    Kari.drop("umbrella-corp")

    Tenant.destroy_all
  end

  it "distinguishes shared recods of in default schema (excluded_models) and per-tenant records" do
    expect(Tenant.table_name).to eq "public.tenants"
    expect(Post.table_name).to eq "posts"

    Tenant.create!(identifier: "test1")
    Tenant.create!(identifier: "test2")
    expect(Tenant.count).to eq 2

    Kari.switch!("acme")
    Tenant.create!(identifier: "test3")
    Post.create!(title: "ACME Second Post")

    expect(Post.count).to eq 2
    expect(Tenant.count).to eq 3

    Kari.switch!("umbrella-corp")
    expect(Post.count).to eq 0
    expect(Tenant.count).to eq 3
  end
end
