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

end
