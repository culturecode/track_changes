module TrackChanges
  class Diff < ActiveRecord::Base
    self.table_name = "track_changes_diffs"

    belongs_to :record, :polymorphic => true

    if Configuration.serialize
      serialize :from, type: Hash, coder: YAML
      serialize :to, type: Hash, coder: YAML
    end

    # Returns the mechanism and note in effect, keyed by column, for those of the two columns
    # this table has. A column the host has not added is left out, so the diff saves without
    # it.
    #
    # @return [Hash{Symbol => String, nil}] nil for a value no enclosing block has set.
    def self.change_details
      { mechanism: TrackChanges.change_mechanism, note: TrackChanges.change_note }.select { |column, _| column_names.include?(column.to_s) }
    end

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
