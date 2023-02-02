# frozen_string_literal: true

module ResourcePolicy
  module Policy
    module AttributesPolicy
      # @private
      #
      # Allows to define policy for single attribute
      class AttributeConfiguration
        DEFAULT_OPTIONS = { if: [] }.freeze
        ALLOWED_ACTIONS = %i[read write].freeze

        attr_reader :name

        def initialize(name, policy_configuration:)
          @name = name
          @allowed_actions = {}
          @policy_configuration = policy_configuration
        end

        def initialize_copy(other)
          super
          @allowed_actions = @allowed_actions.dup.transform_values(&:dup)
        end

        def allowed(*action_types, **options)
          action_types.map(&:to_sym).each do |action|
            allowed_actions[action] = merged_action_options(action, options)
          end
          self
        end

        def conditions_for(action)
          action_conditions = allowed_actions.fetch(action, {}).fetch(:if, [])
          (action_conditions + policy_configuration.group_conditions).uniq
        end

        def configured?
          !defined_actions.empty?
        end

        def defined_actions
          allowed_actions.keys
        end

        def defined_action?(action_name)
          defined_actions.include?(action_name.to_sym)
        end

        def merge(other)
          dup.tap do |new_attribute|
            other.defined_actions.each do |action|
              new_attribute.allowed(action, if: other.conditions_for(action))
            end
          end
        end

        private

        attr_reader :allowed_actions, :policy_configuration

        def merged_action_options(action, new_options)
          previous_options = allowed_actions[action]
          options = previous_options || DEFAULT_OPTIONS.dup
          options[:if] += Array(new_options[:if])
          options[:if].uniq!
          options
        end
      end
    end
  end
end
