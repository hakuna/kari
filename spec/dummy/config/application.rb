# frozen_string_literal: true

require_relative "boot"

require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "action_cable/engine"
require "active_job/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
require "kari"
require "kari/elevators/subdomain"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f

    config.middleware.use Kari::Elevators::Subdomain

    config.active_record.async_query_executor = :global_thread_pool if Rails::VERSION::STRING >= "7.0"

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.kari.excluded_models = ["Tenant"]
    config.kari.tenants = -> { Tenant.pluck(:identifier) }
  end
end
