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

## Usage

In your model

```ruby
class Person < ActiveRecord::Base
  tracks_changes # may also pass an options hash
end
```

### Options
By default all model attributes are tracked, except the primary_key, usually ```id```, ```created_at```, and ```updated_at```.
```:only``` accepts a field name or array of field names to track instead of the default fields
```:except``` accepts a field name or array of field names to ignore
```:methods``` accepts a field name or array of field names to track in addition to the default fields
```:track_timestamps``` accepts a boolean, enabling or disabling tracking of ```created_at``` and ```updated_at```
```:track_primary_key``` accepts a boolean, enabling or disabling tracking of the model's primary key
