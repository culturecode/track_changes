module TrackChanges
  module Controller
    module Base
      # Attributes changes made in each action to the value the controller returns from
      # `method_name`, as `TrackChanges.with_changes_attributed_to` does for a block.
      #
      # @example
      #   attribute_changes_to :current_user, mechanism: "edit interface", only: [:create, :update]
      #
      # @param method_name [Symbol] a controller method returning the source to record.
      # @param options [Hash] optional `mechanism:` and `note:`. A Symbol value names a
      #   controller method called on each request, and any other value is recorded as given.
      #   The remaining options, such as `only:`, are passed to `around_action`.
      def attribute_changes_to(method_name, **options)
        details = options.extract!(:mechanism, :note)
        around_action(**options) do |controller, action|
          source = controller.send(method_name)
          TrackChanges.with_changes_attributed_to(source, **Controller.resolve_change_details(controller, details), &action)
        end
      end

      # Records a mechanism and note with changes made in each action, keeping the current
      # attribution, as `TrackChanges.with_change_details` does for a block.
      #
      # @example
      #   record_change_details mechanism: "bulk edit", note: :bulk_edit_note, only: :bulk_update
      #
      # @param options [Hash] `mechanism:` and `note:`, resolved as in `attribute_changes_to`.
      #   The remaining options, such as `only:`, are passed to `around_action`.
      # @raise [ArgumentError] when neither `mechanism:` nor `note:` is given.
      def record_change_details(**options)
        details = options.extract!(:mechanism, :note)
        raise ArgumentError, "record_change_details needs mechanism: or note:" if details.empty?

        around_action(**options) do |controller, action|
          TrackChanges.with_change_details(**Controller.resolve_change_details(controller, details), &action)
        end
      end
    end

    # Returns `details` with each Symbol value replaced by what that method returns on
    # `controller`.
    def self.resolve_change_details(controller, details)
      details.transform_values { |value| value.is_a?(Symbol) ? controller.send(value) : value }
    end
  end
end
