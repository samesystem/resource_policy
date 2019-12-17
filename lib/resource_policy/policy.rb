# frozen_string_literal: true

module ResourcePolicy
  # Gives policy configuration methods for any policy class
  module Policy
    require 'resource_policy/protected_resource'
    require 'resource_policy/policy/policy_configuration'
    require 'resource_policy/policy/attributes_policy'
    require 'resource_policy/policy/actions_policy'

    # Class methods.
    module ClassMethods
      def policy
        @policy ||= Policy::PolicyConfiguration.new
        yield(@policy) if block_given?
        @policy
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@policy, policy.dup)
      end
    end

    def self.included(receiver)
      receiver.send(:extend, ClassMethods)
      receiver.send(:include, ::ResourcePolicy::Policy::ActionsPolicy)
      receiver.send(:include, ::ResourcePolicy::Policy::AttributesPolicy)
    end
  end
end
