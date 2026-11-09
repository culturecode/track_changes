require "logger"
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "minitest/autorun"
require "track_changes"

# Defined before boot because the engine extends it in `to_prepare`.
class ApplicationController < ActionController::Base
end

module TrackChangesTest
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = __dir__
    config.eager_load = false
    config.logger = Logger.new(nil)
    config.secret_key_base = "test"
  end
end

# Stands in for `config/database.yml`, which the app needs to boot. The connection is
# replaced below.
ENV["DATABASE_URL"] = "sqlite3::memory:"
TrackChangesTest::Application.initialize!

# Keeps only frames from the test files, which stand in for a host's own code. The default
# cleaner keeps frames from a host's `app`, `config`, `lib` and `test` directories.
TEST_FRAMES_ONLY = ->(line) { !line.match?(/_test\.rb:\d+/) }
Rails.backtrace_cleaner.remove_silencers!
Rails.backtrace_cleaner.add_silencer(&TEST_FRAMES_ONLY)

# A shared-cache in-memory database, so connections checked out by other threads see the
# same tables.
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: "file:track_changes_test?mode=memory&cache=shared",
  flags: SQLite3::Constants::Open::READWRITE | SQLite3::Constants::Open::CREATE | SQLite3::Constants::Open::URI
)

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :posts do |t|
    t.string :title
  end

  create_table :track_changes_snapshots do |t|
    t.references :record, polymorphic: true
    t.text :state
    t.timestamps
  end

  create_table :track_changes_diffs do |t|
    t.references :record, polymorphic: true
    t.text :from
    t.text :to
    t.string :action
    t.string :changes_by
    t.string :mechanism
    t.text :note
    t.timestamps
  end
end

class Post < ActiveRecord::Base
  tracks_changes
end

class ActiveSupport::TestCase
  setup do
    TrackChanges::Diff.delete_all
    TrackChanges::Snapshot.delete_all
    Post.delete_all
  end

  private

  # Returns the diff recorded by the most recent save of `post`.
  def last_diff(post)
    post.diffs.reload.first
  end
end
