# frozen_string_literal: true

require_relative "saloon/version"
require_relative "saloon/railtie"

# Saloon
module Saloon
  def self.configure(&block)
    block.call(Rails.application.config.saloon)
  end
end
