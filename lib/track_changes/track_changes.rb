module TrackChanges
  module ActsMethod
    def tracks_changes(options = {})
      extend ClassMethods
      include InstanceMethods

      class_attribute :track_changes_options
      self.track_changes_options = options

      attr_accessor :track_changes # Faux attribute to allow disabling of change tracking on this record
      attr_accessor :track_changes_by # Faux attribute to store who made the changes so we can save it in the diff

      has_one :snapshot, :as => :record, :class_name => 'TrackChanges::Snapshot' # A representation of this record as it was last saved
      has_many :diffs, :as => :record, :class_name => 'TrackChanges::Diff' # A representation of changes made between saves through this record's lifetime

      after_save :persist_tracked_changes
    end
  end

  module ClassMethods
    # Returns the method names to call to fetch the fields tracked for changes
    def track_changes_fields
      fields =  Array(track_changes_options[:only]).collect(&:to_s).presence || self.attribute_names
      fields -= Array(track_changes_options[:except]).collect(&:to_s)
      fields += Array(track_changes_options[:methods]).collect(&:to_s)
      fields -= ['created_at', 'updated_at'] unless track_changes_options[:track_timestamps]
      fields -= [primary_key] unless track_changes_options[:track_primary_key]
    end
  end

  module InstanceMethods
    private

    # Compares the last tracked changes to the current state and saves a diff of the changes
    def persist_tracked_changes
      return if track_changes == false

      action     = id_was.blank? ? 'create' : 'update'
      changes_by = track_changes_by.is_a?(ActiveRecord::Base) ? track_changes_by.id : track_changes_by

      if snapshot
        snapshot.create_diff(:action => action, :changes_by => changes_by)
        snapshot.update
      else
        create_snapshot
        snapshot.create_diff(:action => action, :changes_by => changes_by, :from => {})
      end
    end
  end
end