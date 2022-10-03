# frozen_string_literal: true

class Post < ApplicationRecord
  scope :slow, -> { where("SELECT true FROM pg_sleep(0.2)") }
end
