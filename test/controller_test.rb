require "test_helper"

class ControllerTest < ActiveSupport::TestCase
  class PostsController < ApplicationController
    attribute_changes_to :current_user

    def create
      Post.create!(title: "Draft")
      head :ok
    end

    private

    def current_user
      "Alice"
    end
  end

  test "attributes changes made in an action to the named method's value" do
    dispatch(PostsController, :create)

    assert_equal "Alice", TrackChanges::Diff.last.changes_by
  end

  private

  def dispatch(controller, action)
    status, = controller.action(action).call(Rack::MockRequest.env_for("/", method: "POST"))
    assert_equal 200, status
  end
end
