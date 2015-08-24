module TrackChanges
  module Controller
    module Base
      def attribute_changes_to(method_name)
        around_action do |controller, action_block|
          TrackChanges.with_changes_attributed_to controller.send(method_name), &action_block
        end
      end
    end
  end
end
