# Track Changes

Requires Rails 7.1 or later.

## Installation

Migration
```ruby
class CreateTrackChangesTables < ActiveRecord::Migration[7.1]
  def change
    create_table :track_changes_snapshots do |t|
      t.references :record, :polymorphic => true
      t.text :state
      t.timestamps
    end

    create_table :track_changes_diffs do |t|
      t.references :record, :polymorphic => true
      t.text :from
      t.text :to
      t.string :action
      t.string :changes_by
      t.string :mechanism
      t.text :note
      t.timestamps
    end
  end
end
```

## Configuration

```ruby
TrackChanges::Configuration.cascade_destroy = false # Controls whether tracked changes are deleted when the record is deleted. Can be set to false if an audit trail of destroyed records is desired. Default: true
TrackChanges::Configuration.serialize = false # Controls whether tracked changes are serialized as YAML before being written to the database. Can be set to false if the `state`, `from`, and `to` columns are JSON datatype instead of text. Default: true
```

## Usage

```ruby
class Person < ActiveRecord::Base
  tracks_changes # may also pass an options hash
end
```

```ruby
Person.snapshot_all # Initialize snapshots for existing records so the next time the record is saved a diff can be generated.
Person.tracked_change(status: "approved", assigned_to: "user_123") # Returns a list of diffs where specific attributes changed to the specified values.
```

### Options
By default all model attributes are tracked, except the primary_key, usually ```id```, ```created_at```, and ```updated_at```.

- ```:only``` accepts a field name or array of field names to track instead of the default fields
- ```:except``` accepts a field name or array of field names to ignore
- ```:methods``` accepts a field name or array of field names to track in addition to the default fields
- ```:track_timestamps``` accepts a boolean, enabling or disabling tracking of ```created_at``` and ```updated_at```
- ```:track_primary_key``` accepts a boolean, enabling or disabling tracking of the model's primary key
- ```:track_locking_column``` accepts a boolean, enabling or disabling tracking of the model's locking column


### Attribution
Changes can be attributed to a particular source. The source is saved as a string
in the ```:changes_by column``` of the record. If given an instance of ActiveRecord::Base,
the record's id will be used.

```ruby
# Model-level attribution
person.track_changes_by = 'Joe Changems'
person.save

# Block-level attribution
TrackChanges.with_changes_attributed_to 'Joe Changems' do
  person.save
end

# Controller-level attribution
class MyController < ApplicationController
  attribute_changes_to :current_user
end
```

Block and controller attribution belong to the current thread, so concurrent requests on a
multi-threaded server each record their own. Threads started inside a block do not see its
attribution.

On a fiber-based server such as Falcon, set `config.active_support.isolation_level = :fiber`
so that each fiber has its own attribution. With the default `:thread` isolation, fibers on
the same thread share it.

A process-wide default is recorded when neither the record nor a block sets an
attribution. Set it once at boot, for example in an initializer:

```ruby
TrackChanges.default_attribution = 'System'
```

A block attributed to `nil` records no attribution, even when a default is set.

### Mechanism and note
A change can also record how it was made, in the ```:mechanism``` column, and free text
about that particular change, in the ```:note``` column. Both are optional, and both stay
blank when nothing sets them. They are recorded once the host has added the columns, as
described under [Upgrading from 0.3 to 0.4](#upgrading-from-03-to-04).

```ruby
# Block-level, keeping the current attribution
TrackChanges.with_change_details mechanism: 'nightly import', note: 'Batch 12' do
  person.save
end

# Block-level, with the attribution
TrackChanges.with_changes_attributed_to 'System', mechanism: 'nightly import' do
  person.save
end

# Controller-level
class PeopleController < ApplicationController
  attribute_changes_to :current_user, mechanism: 'edit interface'
  record_change_details mechanism: 'bulk edit', note: :bulk_edit_note, only: :bulk_update
end
```

A nested block keeps the enclosing block's mechanism or note for each key it omits, and an
explicit `nil` clears it. Each block restores the previous values when it ends.

In the controller macros a Symbol names a controller method called on each request, and any
other value is recorded as given. Other options, such as ```:only``` and ```:except```, are
passed to `around_action`.

Read them back with `diff.mechanism` and `diff.note`.

## Upgrading from 0.3 to 0.4

### Rails 7.1
Version 0.4 requires Rails 7.1 or later.

### Attribution is per thread
Block and controller attribution now belong to the current thread. Before
0.4 they were shared by the whole process, so any two threads in one process could record
each other's attribution. That includes overlapping requests on a multi-threaded server such
as Puma, and a background thread in the web process, such as a thread pool running jobs,
that saves tracked records while a request is attributing changes. A single-threaded server
with no such background threads was not affected. Affected rows cannot be corrected after
the fact. If you need to tell them apart, rows recorded before you deployed 0.4 are the ones
affected, and `created_at` dates them.

Two behaviours change:

- Threads started inside a block no longer see its attribution. Set the attribution inside
  the thread.
- `TrackChanges.default_attribution = ...` sets the process-wide default. Inside a block it
  now changes that default rather than the block's attribution. Use
  `with_changes_attributed_to` to set an attribution for a block.

Code that sets attribution only through `with_changes_attributed_to`, `attribute_changes_to`,
`track_changes_by` or a default set at boot needs no change.

### Adding the mechanism and note columns
Add both columns with no default:

```ruby
class AddMechanismAndNoteToTrackChangesDiffs < ActiveRecord::Migration[7.1]
  def change
    add_column :track_changes_diffs, :mechanism, :string
    add_column :track_changes_diffs, :note, :text
  end
end
```

Leave both blank on existing rows. A row recorded before the upgrade says nothing about how
its change was made, so a column default or a backfill would label old changes with a
mechanism they did not have. Treat a blank mechanism as "not recorded", not as any
particular mechanism. New rows record a blank mechanism and note when nothing sets them,
even if the column has a default.

0.4 works before the migration has run. Until the columns exist, changes are recorded without a
mechanism or note, and `diff.mechanism` and `diff.note` raise `NoMethodError`.
