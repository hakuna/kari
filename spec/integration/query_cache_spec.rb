# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Query Cache" do
  before do
    Kari.create("acme")
    Kari.create("umbrella-corp")
  end

  after do
    Kari.drop("acme")
    Kari.drop("umbrella-corp")
  end

  # Query Caching is done on a per-thread basis and it seems Rails limits query cache to controller actions 
  # (https://guides.rubyonrails.org/caching_with_rails.html#sql-caching)
  #
  # Encountered issue in a single controller action:
  # Record.find(1) -> nil (public tenant) 
  # Kari.switch!("acme") 
  # Record.find(1) -> nil, although record exists (acme tenant)
  #
  # Fix is to ensure `cache_sql` clears cache if schema changed 
  # (https://github.com/rails/rails/blob/7-0-stable/activerecord/lib/active_record/connection_adapters/abstract/query_cache.rb)
  it "clears cache upon tenant switching" do
    Kari.connection.enable_query_cache! # simulate cached environment, similar to controller action

    Kari.switch! "umbrella-corp"
    post = Post.create! title: "Umbrella Corp Post"

    expect(Post.count).to eq 1 # warm up connection

    RSpec::Mocks.with_temporary_scope do
      # this query is executed and then cached
      expect(Kari.connection).to receive(:exec_query).and_call_original
      expect(Post.find_by_id(post.id)).to eq post
    end

    RSpec::Mocks.with_temporary_scope do
      # make sure cache works, no execute necessary
      expect(Kari.connection).not_to receive(:exec_query)
      expect(Post.find_by_id(post.id)).to eq post
    end

    # now switch to tenant where posts does not exists
    # if cache is not cleared, Post.find_by_id(post.id) wold hit cached entry from previous tenant
    RSpec::Mocks.with_temporary_scope do
      # make sure this query is executed again
      Kari.switch! "acme"
      expect(Kari.connection).to receive(:exec_query).and_call_original
      expect(Post.find_by_id(post.id)).to be_nil
    end
  end
end
