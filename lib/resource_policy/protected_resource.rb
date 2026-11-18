# frozen_string_literal: true

module ResourcePolicy
  # Generates resource which has same attributes as policy target,
  # but returns `nil` when attribute in not readable according to policy
  class ProtectedResource
    def initialize(policy)
      @policy = policy
    end

    def method_missing(method_name, *args)
      return super unless target_respond_to?(method_name, *args)
      return nil unless policy.attribute(method_name).readable?

      policy_target.public_send(method_name, *args)
    end

    def respond_to_missing?(*args)
      target_respond_to?(*args) || super
    end

    private

    attr_reader :policy

    def target_respond_to?(method_name, *args)
      readable_attribute?(method_name) && policy_target.respond_to?(method_name, *args)
    end

    def readable_attribute?(name)
      attribute = policy.class.policy.configured_attribute(name)
      !attribute.nil? && attribute.defined_action?(:read)
    end

    def policy_target
      policy.policy_target
    end
  end
end
