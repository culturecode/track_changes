module TrackChanges
  class Snapshot < ActiveRecord::Base
    self.table_name = "track_changes_snapshots"

    belongs_to :record, :polymorphic => true

    serialize :state, Hash if Configuration.serialize

    before_save :capture_record_state

    # Returns a hash of the current values for all tracked fields on the record
    def self.record_state(record)
      Hash[record.class.track_changes_fields.collect {|method_name| [method_name, dump_attribute_value(record.send(method_name))]   }]
    end

    def self.dump_attribute_value(value)
      case value
      when ActiveRecord::Relation
        dump_attribute_value(value.to_a).sort
      when Array
        value.map {|member| dump_attribute_value(member) }
      when ActiveRecord::Base
        value.send(value.class.primary_key)
      else
        value
      end
    end

    # Creates a diff object that shows the changes between this snapshot and the record's state
    def create_diff(diff_attributes = {})
      record_state   = self.class.record_state(record)
      snapshot_state = self.state
      from           = {}
      to             = {}

      record.class.track_changes_fields.each do |key|
        if snapshot_state.key?(key) && snapshot_state[key] != record_state[key] # We check for the existence of the key in the snapshot before recording so we don't declare newly tracked attributes as "changed" on their first time recorded
          from[key] = snapshot_state[key]
          to[key] = record_state[key]
        end
      end
      diff_attributes = diff_attributes.reverse_merge(:from => from, :to => to)
      record.diffs.create!(diff_attributes) unless diff_attributes[:from].empty? && diff_attributes[:to].empty?
    end

    # Updates the snapshot to the current record state
    def update
      save
    end

    def capture_record_state
      self.state = self.class.record_state(record)
    end
  end
end
