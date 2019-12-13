module ResourcePolicy
  module Policy
    class MergePolicies
      class OverlappingActionError < ResourcePolicy::Error; end

      def self.call(*args)
        new(*args).call
      end

      def initialize(policy, other_policy)
        @merged_policy = policy.dup
        @other_policy = other_policy
      end

      def call
        merge_actions
        merge_attributes
        merged_policy
      end

      private

      attr_reader :merged_policy, :other_policy

      def merge_actions
        other_policy.actions.values.each do |action|
          raise_overlapping_action_error(action) if merged_policy.action(action.name).configured?
          merged_policy.action(action.name).allowed(if: action.conditions)
        end
      end

      def merge_attributes
        other_policy.attributes.values.each do |attribute|
          attribute.defined_actions.each do |action|
            merged_policy.attribute(attribute.name).allowed(action, if: attribute.conditions_for(action))
          end
        end
      end

      def raise_overlapping_action_error(action)
        error_message = \
        'actions should be defined only once, ' \
        "but #{action.name} was defined multiple times"

        raise OverlappingActionError, error_message
      end
    end
  end
end
