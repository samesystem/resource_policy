# frozen_string_literal: true

module ResourcePolicy
  # Gives policy configuration methods for any policy class
  module Policy
    require 'resource_policy/attributes_policy'
    require 'resource_policy/actions_policy'
    require 'resource_policy/protected_resource'

    def self.included(receiver)
      receiver.send(:include, ::ResourcePolicy::AttributesPolicy)
      receiver.send(:include, ::ResourcePolicy::ActionsPolicy)
    end

    def initialize(*args)
      if method(:initialize).super_method.arity > 0
        super
      else
        super()
      end

      resource_policy_initialize(*args)
    end

    def protected_resource
      @protected_resource ||= ProtectedResource.new(self)
    end

    def action(name)
      actions_policy.public_send(name) if actions_policy.respond_to?(name)
    end

    def attribute(name)
      attributes_policy.public_send(name) if attributes_policy.respond_to?(name)
    end

    def policy_target
      @policy_target
    end

    private

    def resource_policy_initialize(*args)
      @policy_target = args.first
    end
  end
end
