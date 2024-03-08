module TrackChanges
  module Configuration
    mattr_accessor :cascade_destroy, :default => true # Destroy tracked changes when record is destroyed?
    mattr_accessor :serialize, :default => true # Serialize data in ruby before writing to the database. Not necessary if the diff and snapshot data columns are JSON.
  end
end
