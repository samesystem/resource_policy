# frozen_string_literal: true

module ResourcePolicy
  module Policy
    module AttributesPolicy
      # Class which isolates methods defined via attributes_policy config
      class AttributesPolicyModel
        require 'resource_policy/policy/attributes_policy/attribute_policy'

        def initialize(policy)
          @policy = policy
          @policy_item_by_name ||= {}
        end

        def all
          @all ||= config.attributes.values.map { |attribute| policy_item(attribute) }
        end

        def all_allowed_to(status)
          all.select { |attribute| attribute.allowed_to?(status) }
        end

        def method_missing(method_name)
          attribute = config.configured_attribute(method_name)
          return super unless attribute

          policy_item(attribute)
        end

        def respond_to_missing?(method_name, *args)
          !config.configured_attribute(method_name).nil? || super
        end

        private

        attr_reader :policy

        def config
          policy.class.policy
        end

        def policy_item(attribute)
          @policy_item_by_name[attribute.name] ||= AttributePolicy.new(attribute, policy: policy)
        end
      end
    end
  end
end
