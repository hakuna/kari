# frozen_string_literal: true

module Kari
  class Current < ActiveSupport::CurrentAttributes
    attribute :tenant
  end
end
