# frozen_string_literal: true

module ResourcePolicy
  module Policy
    module ActionsPolicy
      # Class which isolates methods defined via actions_policy config
      class ActionsPolicyModel
        require 'resource_policy/policy/actions_policy/action_policy'

        def initialize(policy)
          @policy = policy
          @policy_item_by_name ||= {}
        end

        def method_missing(method_name)
          return super unless config.actions.key?(method_name.to_sym)

          policy_item(method_name.to_sym)
        end

        def actions
          config.actions.keys.map { |name| policy_item(name.to_sym) }
        end

        def allowed_action_names
          actions.select(&:allowed?).map(&:name)
        end

        def respond_to_missing?(method_name, *args)
          config.actions.key?(method_name.to_sym) || super
        end

        private

        attr_reader :policy

        def config
          policy.class.policy
        end

        def policy_item(name)
          @policy_item_by_name[name] ||= ActionPolicy.new(name, policy: policy)
        end
      end
    end
  end
end
