# frozen_string_literal: true

module ResourcePolicy
  module AttributesPolicy
    # Class which isolates methods defined via attributes_policy config
    class AttributesPolicyModel
      require 'resource_policy/attributes_policy/attribute_policy'

      def initialize(policy)
        @policy = policy
        @policy_item_by_name ||= {}
      end

      def all
        @all ||= config.attributes.keys.map do |attribute_name|
          policy_item(attribute_name)
        end
      end

      def all_allowed_to(status)
        all.select { |attribute| attribute.allowed_to?(status) }
      end

      def method_missing(method_name)
        return super unless config.attributes.key?(method_name.to_sym)

        policy_item(method_name.to_sym)
      end

      def respond_to_missing?(method_name, *args)
        config.attributes.key?(method_name.to_sym) || super
      end

      private

      attr_reader :policy

      def config
        policy.class.attributes_policy
      end

      def policy_item(name)
        @policy_item_by_name[name] ||= begin
          attribute = config.attributes.fetch(name)
          AttributePolicy.new(attribute, policy: policy)
        end
      end
    end
  end
end
