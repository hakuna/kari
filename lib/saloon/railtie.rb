# frozen_string_literal: true

module Saloon
  class Railtie < Rails::Railtie
    config.saloon = ActiveSupport::OrderedOptions.new
    config.saloon.excluded_models = []
    config.saloon.schema_names = []
    config.saloon.current_schema = nil
  end
end
