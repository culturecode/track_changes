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

  class ImportsController < ApplicationController
    attribute_changes_to :current_user, mechanism: "edit interface"
    attribute_changes_to :current_user, mechanism: "bulk edit", note: :bulk_edit_note, only: :bulk_create
    record_change_details note: "Corrected", only: :correct
    record_change_details note: :correction_note, only: :correct_with_note

    def create
      Post.create!(title: "Draft")
      head :ok
    end

    alias_method :bulk_create, :create
    alias_method :correct, :create
    alias_method :correct_with_note, :create

    private

    def current_user
      "Alice"
    end

    def bulk_edit_note
      "Rows 1-10"
    end

    def correction_note
      "Typo fixed"
    end
  end

  test "records a literal mechanism given to attribute_changes_to" do
    dispatch(ImportsController, :create)

    assert_equal ["Alice", "edit interface", nil], TrackChanges::Diff.last.slice(:changes_by, :mechanism, :note).values
  end

  test "records the value of a method named by a Symbol, for the actions given in only:" do
    dispatch(ImportsController, :bulk_create)

    assert_equal ["Alice", "bulk edit", "Rows 1-10"], TrackChanges::Diff.last.slice(:changes_by, :mechanism, :note).values
  end

  test "records a note from record_change_details, keeping the enclosing mechanism and attribution" do
    dispatch(ImportsController, :correct)

    assert_equal ["Alice", "edit interface", "Corrected"], TrackChanges::Diff.last.slice(:changes_by, :mechanism, :note).values
  end

  test "records the value of a method named by a Symbol in record_change_details" do
    dispatch(ImportsController, :correct_with_note)

    assert_equal ["Alice", "edit interface", "Typo fixed"], TrackChanges::Diff.last.slice(:changes_by, :mechanism, :note).values
  end

  test "requires a mechanism or note in record_change_details" do
    assert_raises(ArgumentError) { Class.new(ApplicationController) { record_change_details only: :create } }
  end

  private

  def dispatch(controller, action)
    status, = controller.action(action).call(Rack::MockRequest.env_for("/", method: "POST"))
    assert_equal 200, status
  end
end
