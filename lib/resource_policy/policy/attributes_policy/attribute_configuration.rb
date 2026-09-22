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

        attr_reader :name, :nested_policy_builder, :unprotected_reason

        def initialize(name, policy_configuration:)
          @name = name
          @allowed_actions = {}
          @policy_configuration = policy_configuration
        end

        # Declares which policy guards this attribute's value. The block runs on the parent
        # policy instance, so its own dependencies (app_context, current_user, ...) are in scope.
        def nested(&builder)
          @nested_policy_builder = builder
          self
        end

        # Declares that the value needs no policy of its own. Explicit so that it is greppable
        # and shows up in review, rather than being the silent default it is today.
        def unprotected(because: nil)
          @unprotected = true
          @unprotected_reason = because
          self
        end

        def unprotected?
          !!@unprotected
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
            new_attribute.copy_protection_from(other)
          end
        end

        # `merge` and MergePolicies rebuild attributes from their actions only, so without this
        # a `.nested` declaration silently vanishes inside a `c.group` block or an inherited
        # policy - which is where most of them live.
        def copy_protection_from(other)
          nested(&other.nested_policy_builder) if other.nested_policy_builder
          unprotected(because: other.unprotected_reason) if other.unprotected?
          self
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
