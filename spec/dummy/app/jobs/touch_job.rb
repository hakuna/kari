# frozen_string_literal: true

class TouchJob < ApplicationJob
  def perform(post)
    post.touch
  end
end
