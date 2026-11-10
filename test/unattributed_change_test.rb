require "test_helper"

class UnattributedChangeTest < ActiveSupport::TestCase
  DEFAULT_BEHAVIOR = TrackChanges::Configuration.unattributed_change_behavior

  teardown do
    TrackChanges::Configuration.unattributed_change_behavior = DEFAULT_BEHAVIOR
    TrackChanges.default_attribution = nil
  end

  test "reports nothing by default" do
    log = StringIO.new

    with_logger(Logger.new(log)) { Post.create!(title: "Draft") }

    assert_empty log.string
  end

  test "reports nothing when the behavior is nil" do
    TrackChanges::Configuration.unattributed_change_behavior = nil

    assert_nothing_raised { Post.create!(title: "Draft") }
  end

  test "passes the message and callstack to a callable, naming the record and the call site" do
    post = nil
    reports = capture_reports { post = Post.create!(title: "Draft") }; line = __LINE__

    message, callstack = reports.sole
    assert_match(/\ATrackChanges recorded an unattributed create of Post #{post.id} from \S*unattributed_change_test\.rb:#{line}:in /, message)
    assert_kind_of String, callstack.first
  end

  test "reports a change in a block attributed to nil" do
    reports = capture_reports { TrackChanges.with_changes_attributed_to(nil) { Post.create!(title: "Draft") } }

    assert_equal 1, reports.size
  end

  test "reports nothing for an attributed change, including one attributed to the default" do
    TrackChanges.default_attribution = "System"
    post = Post.new(title: "Draft", track_changes_by: "Alice")

    reports = capture_reports do
      post.save!
      Post.create!(title: "Defaulted")
      TrackChanges.with_changes_attributed_to("Bob") { post.update!(title: "Final") }
    end

    assert_empty reports
  end

  test "reports nothing for a save that records no diff" do
    post = Post.create!(title: "Draft", track_changes_by: "Alice")

    reports = capture_reports { post.save! }

    assert_empty reports
  end

  test "logs a warning when the behavior is :log" do
    log = StringIO.new
    TrackChanges::Configuration.unattributed_change_behavior = :log

    with_logger(Logger.new(log)) { Post.create!(title: "Draft") }

    assert_match(/WARN .*TrackChanges recorded an unattributed create of Post \d+ from \S*unattributed_change_test\.rb:\d+/, log.string)
  end

  test "raises and rolls back the save when the behavior is :raise" do
    TrackChanges::Configuration.unattributed_change_behavior = :raise

    assert_raises(TrackChanges::UnattributedChangeError) { Post.create!(title: "Draft") }
    assert_equal 0, Post.count
  end

  test "passes the message to any object that responds to call" do
    messages = []
    reporter = Object.new
    reporter.define_singleton_method(:call) { |message, _callstack| messages << message }
    TrackChanges::Configuration.unattributed_change_behavior = reporter

    Post.create!(title: "Draft")

    assert_equal 1, messages.size
  end

  test "rejects an unknown behavior when it is assigned" do
    assert_raises(ArgumentError) { TrackChanges::Configuration.unattributed_change_behavior = :warn }
    assert_raises(ArgumentError) { TrackChanges::Configuration.unattributed_change_behavior = "log" }
  end

  test "never reports a frame from this gem as the call site" do
    Rails.backtrace_cleaner.remove_silencers!
    reports = capture_reports { Post.create!(title: "Draft") }

    message, = reports.sole
    refute_includes message, "lib/track_changes/"
  ensure
    Rails.backtrace_cleaner.add_silencer(&TEST_FRAMES_ONLY)
  end

  private

  def capture_reports(behavior = nil)
    reports = []
    TrackChanges::Configuration.unattributed_change_behavior = behavior || ->(message, callstack) { reports << [message, callstack] }
    yield
    reports
  end

  def with_logger(logger)
    previous = Rails.logger
    Rails.logger = logger
    yield
  ensure
    Rails.logger = previous
  end
end
