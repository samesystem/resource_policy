# frozen_string_literal: true

module ResourcePolicy
  module Policy
    # Stores all configuration about policy
    class PolicyConfiguration
      require 'resource_policy/policy/action_policy_configuration'

      require 'resource_policy/policy/attributes_policy/attribute_configuration'
      require 'resource_policy/policy/merge_policies'

      EmptyConfiguration = Class.new do
        def group_conditions
          []
        end
      end

      EMPTY_CONFIGURATION = EmptyConfiguration.new

      def initialize(parent_configuration: EMPTY_CONFIGURATION, extra_group_conditions: [])
        @actions = {}
        @attributes = {}
        @parent_configuration = parent_configuration
        @extra_group_conditions = extra_group_conditions
      end

      def initialize_copy(_other)
        @actions = @actions.dup.each.with_object({}) { |(key, value), result| result[key] = value.dup }
        @attributes = @attributes.dup.each.with_object({}) { |(key, value), result| result[key] = value.dup }
      end

      def policy_target(policy_target_name = nil)
        @policy_target = policy_target_name if policy_target_name
        @policy_target
      end

      def attribute(attribute_name)
        symbolized_name = attribute_name.to_sym

        @attributes[symbolized_name] ||= AttributesPolicy::AttributeConfiguration.new(
          symbolized_name, policy_configuration: self
        )
      end

      def attributes
        @attributes.select { |_name, action| action.configured? }
      end

      def actions
        @actions.select { |_name, action| action.configured? }
      end

      def action(attribute_name)
        symbolized_name = attribute_name.to_sym

        @actions[symbolized_name] ||= ActionPolicyConfiguration.new(
          symbolized_name, policy_configuration: self
        )
      end

      def group(*new_conditions)
        return @group if new_conditions.empty?

        unique_new_conditions = new_conditions.map(&:to_sym).uniq
        group_config = self.class.new(
          parent_configuration: self,
          extra_group_conditions: unique_new_conditions
        )

        yield(group_config)
        tap { |config| config.merge(group_config) }
      end

      def group_conditions
        (parent_configuration.group_conditions + extra_group_conditions).uniq
      end

      def merge(other)
        MergePolicies.call(self, other)
      end

      protected

      attr_reader :extra_group_conditions, :parent_configuration
    end
  end
end
