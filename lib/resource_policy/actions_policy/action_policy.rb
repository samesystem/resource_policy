# frozen_string_literal: true

module ResourcePolicy
  module ActionsPolicy
    # Contains information about single action
    class ActionPolicy
      attr_reader :name

      def initialize(name, policy:)
        @name = name.to_sym
        @policy = policy
      end

      def allowed?
        return @allowed if defined?(@allowed)

        conditions = policy_config.conditions_for(name)
        @allowed = conditions.all? { |condition| policy.send(condition) }
      end

      private

      attr_reader :policy

      def policy_config
        policy.class.actions_policy
      end
    end
  end
end
