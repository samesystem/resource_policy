# frozen_string_literal: true

module ResourcePolicy
  module ActionsPolicy
    # @private
    #
    # Stores configuration for action policy.
    class PolicyConfiguration
      class OverlappingActionError < StandardError; end

      include ::ResourcePolicy::Concerns::PolicyConfigurable

      def action_names
        conditions_by_action.keys - [:all]
      end

      def merge(other)
        assert_no_overlapping_action_names(other)

        other.action_names.each do |action_name|
          allowed_to(action_name, if: other.conditions_for(action_name))
        end
      end

      private

      def assert_no_overlapping_action_names(other)
        overlapping_actions = action_names & other.action_names
        return if overlapping_actions.empty?

        error_message = \
          "actions should be defined once, but #{overlapping_actions} where defined in multiple places"
        raise OverlappingActionError, error_message
      end
    end
  end
end
