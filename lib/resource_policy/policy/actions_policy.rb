# frozen_string_literal: true

module ResourcePolicy
  module Policy
    # Allows to define actions policy using configuration block.
    #
    # Usage example:
    #
    # class SomeModelPolicy
    #   include Policy::ActionsPolicy
    #
    #   policy do |c|
    #     c.action(:create).allowed(if: :current_user_is_admin?)
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
      require 'resource_policy/policy/actions_policy/actions_policy_model'

      def actions_policy
        @actions_policy ||= ActionsPolicyModel.new(self)
      end

      def action(name)
        actions_policy.public_send(name) if actions_policy.respond_to?(name)
      end
    end
  end
end
