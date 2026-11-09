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
    # @param details [Hash] optional `mechanism:` and `note:`, applied to the block as
    #   `with_change_details` applies them.
    # @return the value of the block.
    # @raise [ArgumentError] when `details` has a key other than `mechanism` or `note`.
    def with_changes_attributed_to(source, **details, &block)
      with_change_context(attribution: source, **validate_change_details(details), &block)
    end

    # Records `mechanism` and `note` with changes made during the block, keeping the current
    # attribution, then restores the previous values. Each key that is omitted keeps the
    # enclosing block's value, and an explicit nil clears it. Both are recorded only once the
    # host has added the `mechanism` and `note` columns to `track_changes_diffs`.
    #
    # @example
    #   TrackChanges.with_change_details(mechanism: "nightly import", note: "Batch 12") do
    #     Post.find_each(&:recalculate!)
    #   end
    #
    # @param details [Hash] `mechanism:`, how the change was made, and `note:`, free text
    #   about this change. Either may be omitted.
    # @return the value of the block.
    # @raise [ArgumentError] when `details` has a key other than `mechanism` or `note`.
    def with_change_details(**details, &block)
      with_change_context(**validate_change_details(details), &block)
    end

    # Returns the mechanism set by the innermost enclosing block in the current execution
    # context.
    #
    # @return [String, nil] nil outside any block that set one.
    def change_mechanism
      change_context[:mechanism]
    end

    # Returns the note set by the innermost enclosing block in the current execution
    # context.
    #
    # @return [String, nil] nil outside any block that set one.
    def change_note
      change_context[:note]
    end

    private

    def validate_change_details(details)
      details.assert_valid_keys(:mechanism, :note)
      details
    end

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
