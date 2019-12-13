# frozen_string_literal: true

module ResourcePolicy
  module Policy
    # @private
    #
    # Stores configuration for action policy.
    class ActionPolicyConfiguration
      attr_reader :name

      def initialize(name, policy_configuration:)
        @name = name.to_sym
        @policy_configuration = policy_configuration
        @extra_conditions = []
        @configured = false
      end

      def allowed(options = {})
        @extra_conditions = (@extra_conditions + Array(options[:if])).uniq
        @configured = true
        self
      end

      def conditions
        policy_configuration.group_conditions + @extra_conditions
      end

      def configured?
        @configured
      end

      private

      attr_reader :policy_configuration
    end
  end
end
