# frozen_string_literal: true

module ResourcePolicy
  # Gives policy configuration methods for any policy class
  module Policy
    require 'resource_policy/attributes_policy'
    require 'resource_policy/actions_policy'

    def self.included(receiver)
      receiver.send(:include, ::ResourcePolicy::AttributesPolicy)
      receiver.send(:include, ::ResourcePolicy::ActionsPolicy)
    end

    def action(name)
      actions_policy.public_send(name) if actions_policy.respond_to?(name)
    end

    def attribute(name)
      attributes_policy.public_send(name) if attributes_policy.respond_to?(name)
    end
  end
end