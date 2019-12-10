# frozen_string_literal: true

module ResourcePolicy
  # Allows to define actions policy using configuration block.
  #
  # Usage example:
  #
  # class SomeModelPolicy
  #   include Policy::ActionsPolicy
  #
  #   actions_policy do |c|
  #     c.allowed_to(:create, if: :current_user_is_admin?)
  #   end
  #
  #   private
  #
  #   def current_user_is_admin?
  #      current_user.admin?
  #   end
  #   ...
  # end
  module ActionsPolicy
    require 'resource_policy/actions_policy/policy_configuration'
    require 'resource_policy/actions_policy/actions_policy_model'

    # Used for defining class methods
    module ClassMethods
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@actions_policy, actions_policy.dup)
      end

      def actions_policy
        @actions_policy ||= ActionsPolicy::PolicyConfiguration.new

        if block_given?
          yield(@actions_policy)
        end

        @actions_policy
      end
    end

    def self.included(base)
      base.extend(::ResourcePolicy::ActionsPolicy::ClassMethods)
    end

    def actions_policy
      @actions_policy ||= ActionsPolicyModel.new(self)
    end
  end
end
