# frozen_string_literal: true

module ResourcePolicy
  module Policy
    module AttributesPolicy
      # @private
      #
      # Stores information about access level of single attribute.
      class AttributePolicy
        def initialize(attribute_config, policy:)
          @policy = policy
          @attribute_config = attribute_config
        end

        def name
          attribute_config.name
        end

        def readable?
          allowed_to?(:read)
        end

        def writable?
          allowed_to?(:write)
        end

        # Builds the policy guarding this attribute's value, or nil when none is declared.
        def nested_policy_for(value)
          builder = attribute_config.nested_policy_builder
          return nil unless builder

          policy.instance_exec(value, &builder)
        end

        def unprotected?
          attribute_config.unprotected?
        end

        def allowed_to?(access_level)
          @allowed_to ||= {}
          level_name = access_level.to_sym

          return @allowed_to[level_name] if @allowed_to.key?(level_name)

          @allowed_to[level_name] = fetch_allowed_to(level_name)
        end

        private

        attr_reader :policy, :attribute_config

        def fetch_allowed_to(access_level)
          return false unless attribute_config.defined_actions.include?(access_level)

          conditions = attribute_config.conditions_for(access_level)
          conditions.all? { |condition| policy.send(condition) }
        end
      end
    end
  end
end
