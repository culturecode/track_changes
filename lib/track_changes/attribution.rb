module TrackChanges
  CHANGE_CONTEXT_KEY = :track_changes_change_context
  private_constant :CHANGE_CONTEXT_KEY

  class << self
    # Sets the attribution recorded when neither the record nor an enclosing block sets one.
    # It is shared by every thread in the process, so set it once at boot, for example to
    # "System".
    #
    # @param source [ActiveRecord::Base, String, nil]
    attr_writer :default_attribution

    # Returns the attribution recorded for changes made now: the one set by the innermost
    # `with_changes_attributed_to` block in the current execution context, else the
    # process-wide default.
    #
    # @return [ActiveRecord::Base, String, nil] nil when the innermost block was given nil,
    #   or when no block is open and no default is set.
    def default_attribution
      change_context.fetch(:attribution) { @default_attribution }
    end

    # Attributes changes recorded during the block to `source`, then restores the previous
    # attribution, including when the block raises. The attribution belongs to the current
    # execution context, which is the thread, or the fiber when
    # `config.active_support.isolation_level` is :fiber. Threads started inside the block do
    # not see it.
    #
    # @param source [ActiveRecord::Base, String, nil] an Active Record source is recorded by
    #   id. nil records no attribution, even when a default is set.
    # @return the value of the block.
    def with_changes_attributed_to(source, &block)
      with_change_context(attribution: source, &block)
    end

    private

    # Merges `values` over the enclosing block's context for the duration of the block.
    def with_change_context(**values)
      previous = ActiveSupport::IsolatedExecutionState[CHANGE_CONTEXT_KEY]
      ActiveSupport::IsolatedExecutionState[CHANGE_CONTEXT_KEY] = change_context.merge(values).freeze
      yield
    ensure
      ActiveSupport::IsolatedExecutionState[CHANGE_CONTEXT_KEY] = previous
    end

    # Returns the values set by enclosing blocks in the current execution context, keyed by
    # name.
    # Empty outside any block.
    def change_context
      ActiveSupport::IsolatedExecutionState[CHANGE_CONTEXT_KEY] || {}
    end
  end
end
