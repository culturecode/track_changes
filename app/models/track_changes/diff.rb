module TrackChanges
  class Diff < ActiveRecord::Base
    self.table_name = "track_changes_diffs"

    belongs_to :record, :polymorphic => true

    serialize :from, Hash
    serialize :to, Hash

    # Returns changes but only those where the string representation of the value has changed
    def visible_changes
      changes.select {|key, (from, to)| (from.present? || to.present?) && (from.to_s != to.to_s) }
    end

    # Returns a hash of changes where the key is the field name
    # and the value is an array of the from value and the to value
    def changes
      Hash[(from.keys + to.keys).collect do |key|
        [key, [from[key], to[key]]]
      end]
    end
  end
end
