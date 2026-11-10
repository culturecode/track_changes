module TrackChanges
  module Configuration
    mattr_accessor :cascade_destroy, :default => true # Destroy tracked changes when record is destroyed?
    mattr_accessor :serialize, :default => true # Serialize data in ruby before writing to the database. Not necessary if the diff and snapshot data columns are JSON.
    mattr_reader :unattributed_change_behavior, :default => :ignore # How to report a change recorded with a blank `changes_by`. See `unattributed_change_behavior=`.

    UNATTRIBUTED_CHANGE_BEHAVIORS = [nil, :ignore, :log, :raise].freeze

    # Sets how a change recorded with a blank `changes_by` is reported, as
    # `TrackChanges::UnattributedChange.report` describes.
    #
    # @param behavior [Symbol, nil, #call] :ignore or nil, :log, :raise, or an object
    #   responding to `call`, which is given the message and the callstack.
    # @raise [ArgumentError] when `behavior` is none of these, so a typo fails at boot.
    def self.unattributed_change_behavior=(behavior)
      unless UNATTRIBUTED_CHANGE_BEHAVIORS.include?(behavior) || behavior.respond_to?(:call)
        raise ArgumentError, "unattributed_change_behavior must be :ignore, nil, :log, :raise, or respond to call; got #{behavior.inspect}"
      end

      @@unattributed_change_behavior = behavior
    end
  end
end
