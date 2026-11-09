require "test_helper"

class ChangeDetailsTest < ActiveSupport::TestCase
  test "records the mechanism and note set for a block, keeping the attribution" do
    post = Post.new(title: "Draft")

    TrackChanges.with_changes_attributed_to("Alice") do
      TrackChanges.with_change_details(mechanism: "nightly import", note: "Batch 12") { post.save! }
    end

    assert_equal ["Alice", "nightly import", "Batch 12"], last_diff(post).slice(:changes_by, :mechanism, :note).values
  end

  test "records the mechanism and note given with the attribution" do
    post = Post.new(title: "Draft")

    TrackChanges.with_changes_attributed_to("System", mechanism: "nightly import", note: "Batch 12") { post.save! }

    assert_equal ["System", "nightly import", "Batch 12"], last_diff(post).slice(:changes_by, :mechanism, :note).values
  end

  test "leaves both blank when no block sets them" do
    post = Post.new(title: "Draft")

    TrackChanges.with_changes_attributed_to("Alice") { post.save! }

    assert_equal [nil, nil], last_diff(post).slice(:mechanism, :note).values
  end

  test "records blank values over a column default when no block sets them" do
    connection = ActiveRecord::Base.connection
    connection.change_column_default :track_changes_diffs, :mechanism, from: nil, to: "edit interface"
    TrackChanges::Diff.reset_column_information
    post = Post.new(title: "Draft")

    post.save!

    assert_nil last_diff(post).mechanism
  ensure
    connection.change_column_default :track_changes_diffs, :mechanism, from: "edit interface", to: nil
    TrackChanges::Diff.reset_column_information
  end

  test "keeps omitted values from the enclosing block, clears explicit nils, and restores both" do
    post = Post.create!(title: "Draft")

    TrackChanges.with_change_details(mechanism: "nightly import", note: "Batch 12") do
      TrackChanges.with_change_details(note: "Retry") { post.update!(title: "Retried") }
      TrackChanges.with_change_details(note: nil) { post.update!(title: "Cleared") }
      post.update!(title: "Outer")
    end
    post.update!(title: "After")

    recorded = post.diffs.reorder(:id).pluck(:mechanism, :note).drop(1)
    assert_equal [["nightly import", "Retry"], ["nightly import", nil], ["nightly import", "Batch 12"], [nil, nil]], recorded
  end

  test "rejects a key other than mechanism or note" do
    assert_raises(ArgumentError) { TrackChanges.with_change_details(mechansim: "typo") {} }
    assert_raises(ArgumentError) { TrackChanges.with_changes_attributed_to("Alice", source: "typo") {} }
  end

  test "saves without either until the host adds the columns" do
    without_change_detail_columns do
      post = Post.new(title: "Draft")

      TrackChanges.with_change_details(mechanism: "nightly import", note: "Batch 12") { post.save! }

      assert_equal 1, post.diffs.count
    end
  end

  private

  def without_change_detail_columns
    connection = ActiveRecord::Base.connection
    connection.remove_column :track_changes_diffs, :mechanism
    connection.remove_column :track_changes_diffs, :note
    TrackChanges::Diff.reset_column_information
    yield
  ensure
    connection.add_column :track_changes_diffs, :mechanism, :string
    connection.add_column :track_changes_diffs, :note, :text
    TrackChanges::Diff.reset_column_information
  end
end
