module TrackChanges
  # Raised for a change recorded without attribution when
  # `Configuration.unattributed_change_behavior` is :raise.
  class UnattributedChangeError < StandardError
  end

  module UnattributedChange
    # Reports `diff` according to `Configuration.unattributed_change_behavior`:
    #
    # - :ignore or nil does nothing.
    # - :log writes a warning to `Rails.logger`.
    # - :raise raises `UnattributedChangeError` after the diff is written. Within a save the
    #   diff is recorded in an `after_save` callback, so this rolls the save back. The
    #   class-level `persist_tracked_changes` runs outside a transaction, so there the diff
    #   and snapshot stay written and the remaining records are not processed.
    # - Any other value is called with the message and the callstack.
    #
    # The message names the record and the first frame that led to the change, skipping this
    # gem's own frames and keeping the frames `Rails.backtrace_cleaner` keeps.
    #
    # @param diff [TrackChanges::Diff] a diff whose `changes_by` is blank.
    # @raise [UnattributedChangeError] when the behaviour is :raise.
    def self.report(diff)
      behavior = Configuration.unattributed_change_behavior
      return if behavior.nil? || behavior == :ignore

      callstack = caller_locations.map(&:to_s)
      message = message_for(diff, callstack)

      case behavior
      when :log then Rails.logger&.warn(message)
      when :raise then raise UnattributedChangeError, message
      else behavior.call(message, callstack)
      end
    end

    def self.message_for(diff, callstack)
      message = "TrackChanges recorded an unattributed #{diff.action} of #{diff.record_type} #{diff.record_id}"
      gem_dirs = %w[lib app].map { |dir| "#{TrackChanges::Engine.root.join(dir)}/" }
      call_site = Rails.backtrace_cleaner.clean(callstack.reject { |frame| frame.start_with?(*gem_dirs) }).first
      call_site ? "#{message} from #{call_site}" : message
    end
  end
end
