module TrackChanges
  module Configuration
    mattr_accessor :cascade_destroy, :default => true # Destroy tracked changes when record is destroyed?
  end
end
