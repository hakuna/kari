class TouchJob < ApplicationJob

  def perform(post)
    post.touch
  end

end
