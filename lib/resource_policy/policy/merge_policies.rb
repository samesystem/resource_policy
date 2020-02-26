# frozen_string_literal: true

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
          policy.action(action.name).allowed(if: action.conditions)
        end
      end

      def merge_attributes
        other_policy.attributes.values.each do |attribute|
          attribute.defined_actions.each do |action_name|
            conditions = attribute.conditions_for(action_name)
            policy.attribute(attribute.name).allowed(action_name, if: conditions)
          end
        end
      end
    end
  end
end
