# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Posts", type: :request do
  before do
    Kari.create("acme")
    Kari.create("umbrella-corp")
  end

  after do
    Kari.drop("acme")
    Kari.drop("umbrella-corp")
  end

  it "limits posts to the tenant specified by the subdomain" do
    host! "acme.kari.test"
    post "/posts", params: { post: { title: "ACME Post", content: "This is content" } }
    expect(response).to have_http_status(:found)

    get "/posts"
    expect(response.body).to include("ACME Post")

    # switch tenant
    host! "umbrella-corp.kari.test"
    get "/posts"
    expect(response.body).not_to include("ACME Post")

    post "/posts", params: { post: { title: "New G-Virus", content: "This is classified information" } }
    expect(response).to have_http_status(:found)

    get "/posts"
    expect(response.body).to include("New G-Virus")
    expect(response.body).not_to include("ACME Post")
  end

  context "async queries (Rails 7.0+)", if: Rails::VERSION::MAJOR >= 7 do
    before do
      self.use_transactional_tests = false
    end

    it "supports async retrieval of posts" do
      # ensure dummy app uses thread pool for load_async
      expect(Rails.application.config.active_record.async_query_executor).to eq :global_thread_pool

      Kari.switch!("acme")

      Post.create!(title: "ACME1")
      Post.create!(title: "ACME2")

      expect(Post.count).to eq 2

      Kari.switch!("umbrella-corp")
      post = Post.create!(title: "GVirus")

      expect(Post.count).to eq 1
      result = Post.slow.load_async
      expect(result).to be_scheduled

      # now switch to other tenant
      Kari.switch!("acme")

      # wait for result, ensure async query was executed
      # within correct tenant schema
      res = result.to_a
      expect(res.count).to eq 1
      expect(res).to eq [post]
    end
  end
end
