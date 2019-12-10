# frozen_string_literal: true

module ResourcePolicy
  module ActionsPolicy
    # Class which isolates methods defined via actions_policy config
    class ActionsPolicyModel
      require 'resource_policy/actions_policy/action_policy'

      def initialize(policy)
        @policy = policy
        @policy_item_by_name ||= {}
      end

      def method_missing(method_name)
        return super unless config.action_names.include?(method_name.to_sym)

        policy_item(method_name.to_sym)
      end

      def respond_to_missing?(method_name, *args)
        config.action_names.include?(method_name.to_sym) || super
      end

      private

      attr_reader :policy

      def config
        policy.class.actions_policy
      end

      def policy_item(name)
        @policy_item_by_name[name] ||= ActionPolicy.new(name, policy: policy)
      end
    end
  end
end
