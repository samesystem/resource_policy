module ResourcePolicy
  module Concerns
    # Contains methods shared by all policy configuration classes
    module PolicyConfigurable
      EmptyConfiguration = Class.new do
        def conditions_for(*_args)
          []
        end
      end

      EMPTY_CONFIGURATION = EmptyConfiguration.new

      def initialize(parent_configuration: EMPTY_CONFIGURATION)
        @parent_configuration = parent_configuration
        @conditions_by_action = {}
      end

      def allowed_to(*action_types, **options)
        action_types.each do |action_type|
          conditions = conditions_for(action_type) + Array(options[:if])
          conditions_by_action[action_type.to_sym] = conditions.map(&:to_sym).uniq
        end
      end

      def conditions_for(action_type)
        local_conditions = conditions_by_action.fetch(action_type.to_sym, []) + all_action_conditions
        (parent_configuration.conditions_for(action_type) + local_conditions).uniq
      end

      def group(*new_conditions)
        group_config = self.class.new(parent_configuration: self)
        group_config.allowed_to(:all, if: new_conditions)
        yield(group_config)
        tap { |config| config.merge(group_config) }
      end

      protected

      def parent_configuration
        @parent_configuration
      end

      def conditions_by_action
        @conditions_by_action
      end

      private

      def all_action_conditions
        conditions_by_action.fetch(:all, [])
      end
    end
  end
end
