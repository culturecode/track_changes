module TrackChanges
  module Model
    module Base
      def tracks_changes(options = {})
        extend ClassMethods
        include InstanceMethods

        class_attribute :track_changes_options
        self.track_changes_options = options

        attr_accessor :track_changes # Faux attribute to allow disabling of change tracking on this record
        attr_writer   :track_changes_by # Faux attribute to store who made the changes so we can save it in the diff

        has_one :snapshot, :as => :record, :class_name => 'TrackChanges::Snapshot' # A representation of this record as it was last saved
        has_many :diffs, lambda { reorder('id DESC') }, :as => :record, :class_name => 'TrackChanges::Diff' # A representation of changes made between saves through this record's lifetime

        after_save :persist_tracked_changes
      end
    end

    module ClassMethods
      # Returns the method names to call to fetch the fields tracked for changes
      def track_changes_fields
        fields =  Array(track_changes_options[:only]).collect(&:to_s).presence || default_track_changes_fields
        fields -= Array(track_changes_options[:except]).collect(&:to_s)
        fields += Array(track_changes_options[:methods]).collect(&:to_s)
        fields -= ['created_at', 'updated_at'] unless track_changes_options[:track_timestamps]
        fields -= [primary_key] unless track_changes_options[:track_primary_key]
        fields -= [locking_column] unless track_changes_options[:track_locking_column]

        return fields.uniq
      end

      def default_track_changes_fields
        attribute_names - stored_attributes.keys.map(&:to_s) + stored_attributes.values.flatten.map(&:to_s)
      end

      # Create snapshots for all records so that the next changes made are captured
      # This can be used to init track changes on existing records
      def snapshot_all
        # Update existing snapshots
        joins(:snapshot).find_each {|record| record.snapshot.update }
        # Create new snapshots
        where.not(:id => joins(:snapshot)).find_each(&:create_snapshot)
      end

      # Record a diff and update the snapshot for all records in the scope
      # This can be used to record a diff after an `update_all`.
      def persist_tracked_changes(track_changes_by: nil)
        find_each do |record|
          record.track_changes_by = track_changes_by
          record.persist_tracked_changes
        end
      end
    end

    module InstanceMethods
      def track_changes_by
        @track_changes_by || TrackChanges.default_attribution
      end

      # Compares the last tracked changes to the current state and saves a diff of the changes
      def persist_tracked_changes
        return if track_changes == false

        new_record = was_new_record_before_save?
        action     = new_record ? 'create' : 'update'
        changes_by = track_changes_by.is_a?(ActiveRecord::Base) ? track_changes_by.id : track_changes_by

        if snapshot
          snapshot.create_diff(:action => action, :changes_by => changes_by)
          snapshot.update
        elsif new_record
          create_snapshot
          snapshot.create_diff(:action => action, :changes_by => changes_by, :from => {}, :to => snapshot.state)
        else # We started tracking changes after the item was created
          create_snapshot
          snapshot.create_diff(:action => action, :changes_by => changes_by, :from => {})
        end
      end

      def was_new_record_before_save?
        if !respond_to?(:attribute_before_last_save) # Rails < 6
          id_was.blank?
        elsif saved_change_to_attribute?(:id) # Rails <=5
          attribute_before_last_save(:id).blank?
        else # Allow this method to be used outside of a transaction, e.g. after a bulk update
          new_record?
        end
      end
    end
  end
end
