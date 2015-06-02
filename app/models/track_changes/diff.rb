module TrackChanges
  class Diff < ActiveRecord::Base
    self.table_name = "track_changes_diffs"

    belongs_to :record, :polymorphic => true

    serialize :from, Hash
    serialize :to, Hash

    # Returns a hash of changes where the key is the field name
    # and the value is an array of the from value and the to value
    def changes
      Hash[from.collect do |key, was|
        [key, [was, to[key]]]
      end]
    end
  end
end
