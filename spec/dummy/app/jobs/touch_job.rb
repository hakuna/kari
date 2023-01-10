# frozen_string_literal: true

class TouchJob < ApplicationJob
  rescue_from Kari::SchemaNotFound do 
    Rails.logger.error "All is lost!"
  end

  def perform(post)
    post.touch
  end
end
