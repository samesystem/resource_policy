module ResourcePolicy
  module Policy
    # Service object using for merging two policy configurations
    class MergePolicies
      class OverlappingActionError < ResourcePolicy::Error; end

      def self.call(*args)
        new(*args).call
      end

      def initialize(policy, other_policy)
        @policy = policy
        @other_policy = other_policy
      end

      def call
        merge_actions
        merge_attributes
        policy
      end

      private

      attr_reader :policy, :other_policy

      def merge_actions
        other_policy.actions.values.each do |action|
          raise_overlapping_action_error(action) if policy.action(action.name).configured?
          policy.action(action.name).allowed(if: action.conditions)
        end
      end

      def merge_attributes
        ensure_non_overlapping_attributes

        other_policy.attributes.values.each do |attribute|
          attribute.defined_actions.each do |action_name|
            conditions = attribute.conditions_for(action_name)
            policy.attribute(attribute.name).allowed(action_name, if: conditions)
          end
        end
      end

      def raise_overlapping_action_error(action)
        error_message = \
          'actions should be defined only once, ' \
          "but #{action.name} was defined multiple times"

        raise OverlappingActionError, error_message
      end

      def ensure_non_overlapping_attributes
        other_policy.attributes.values.each do |attribute|
          attribute.defined_actions.each do |action_name|
            if policy.attribute(attribute.name).defined_actions.include?(action_name)
              raise_overlapping_attribute_error(attribute, action_name)
            end
          end
        end
      end

      def raise_overlapping_attribute_error(attribute, action)
        error_message = \
          'attribute actions should be defined only once, but ' \
          "attribute #{attribute.name.inspect} action #{action.inspect} " \
          'was defined multiple times'

        raise OverlappingActionError, error_message
      end
    end
  end
end
