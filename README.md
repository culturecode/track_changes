# Track Changes

## Installation

Migration
```ruby
class CreateTrackChangesTables < ActiveRecord::Migration
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
      t.timestamps
    end
  end
end
```

## Configuration

```ruby
TrackChanges::Configuration.cascade_destroy = false # Controls whether tracked changes are deleted when the record is deleted. Can be set to false if an audit trail of destroyed records is desired. Default: true
```

## Usage

```ruby
class Person < ActiveRecord::Base
  tracks_changes # may also pass an options hash
end
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
