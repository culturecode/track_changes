require "test_helper"

class AttributionTest < ActiveSupport::TestCase
  teardown do
    TrackChanges.default_attribution = nil
  end

  test "records the attribution set on the record" do
    post = Post.new(title: "Draft")
    post.track_changes_by = "Alice"
    post.save!

    assert_equal "Alice", last_diff(post).changes_by
  end

  test "records the attribution set for a block, and restores it when the block ends" do
    post = Post.create!(title: "Draft")

    TrackChanges.with_changes_attributed_to("Alice") { post.update!(title: "Final") }
    post.update!(title: "Published")

    assert_equal [nil, "Alice", nil], post.diffs.reorder(:id).pluck(:changes_by)
  end

  test "restores the outer attribution when a nested block ends" do
    post = Post.create!(title: "Draft")

    TrackChanges.with_changes_attributed_to("Alice") do
      TrackChanges.with_changes_attributed_to("Bob") { post.update!(title: "Final") }
      post.update!(title: "Published")
    end

    assert_equal [nil, "Bob", "Alice"], post.diffs.reorder(:id).pluck(:changes_by)
  end

  test "records the id of an Active Record attribution" do
    author = Post.create!(title: "Author")
    post = Post.new(title: "Draft")

    TrackChanges.with_changes_attributed_to(author) { post.save! }

    assert_equal author.id.to_s, last_diff(post).changes_by
  end

  test "prefers the record's attribution over the block's" do
    post = Post.new(title: "Draft", track_changes_by: "Alice")

    TrackChanges.with_changes_attributed_to("Bob") { post.save! }

    assert_equal "Alice", last_diff(post).changes_by
  end

  test "falls back to the default attribution set outside any block" do
    TrackChanges.default_attribution = "System"
    post = Post.create!(title: "Draft")

    assert_equal "System", last_diff(post).changes_by
  end

  test "records no attribution inside a block attributed to nil, even with a default set" do
    TrackChanges.default_attribution = "System"
    post = Post.new(title: "Draft")

    TrackChanges.with_changes_attributed_to(nil) { post.save! }

    assert_nil last_diff(post).changes_by
  end

  test "returns the value of the block" do
    assert_equal :result, TrackChanges.with_changes_attributed_to("Alice") { :result }
  end
end
