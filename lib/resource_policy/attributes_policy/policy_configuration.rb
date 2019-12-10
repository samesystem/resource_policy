# frozen_string_literal: true

module ResourcePolicy
  module AttributesPolicy
    # @private
    #
    # Stores configuration for attributes policy.
    class PolicyConfiguration
      require 'resource_policy/concerns/policy_configurable'
      require 'resource_policy/attributes_policy/attribute_configuration'


      include ResourcePolicy::Concerns::PolicyConfigurable

      def initialize(*args)
        super
        @attributes = {}
      end

      def initialize_copy(other)
        super
        @attributes = @attributes.dup.transform_values(&:dup)
      end

      def attribute(name)
        symbolized_name = name.to_sym
        @attributes[symbolized_name] ||= AttributeConfiguration.new(
          symbolized_name,
          attributes_policy: self
        )
      end

      def attributes
        @attributes.select { |_, attribute| attribute.configured? }
      end

      def merge(other)
        (attributes.keys + other.attributes.keys).uniq.each do |attribute_name|
          other_attribute = other.attribute(attribute_name)
          @attributes[attribute_name] = attribute(attribute_name).merge(other_attribute)
        end
      end

      private

      attr_reader :parent_configuration, :conditions_by_action

      def all_action_conditions
        conditions_by_action.fetch(:all, [])
      end
    end
  end
end
