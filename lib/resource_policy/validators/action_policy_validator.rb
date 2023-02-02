# frozen_string_literal: true

# Available options:
#
#   * `:allowed_to` (required) - action type which we need to check.
#   * `:as` (optional) - key which will be used to display errors.
#
# Usage example:
#
#   class SomeClass
#     validates :some_policy, 'resource_policy/action': { allowed_to: :create, as: :some_item }
#
#     def some_policy
#       SomePolicy.new
#     end
#   end
#
module ResourcePolicy
  class ActionValidator < ActiveModel::EachValidator
    def validate_each(record, default_attribute, policy)
      attribute = options.fetch(:as, default_attribute)
      action_policy = policy.action(action_name)
      validate_action_policy(action_policy, record:, attribute:)
    end

    private

    def validate_action_policy(policy, record:, attribute:)
      if policy.nil?
        add_missing_policy_error_for(record, attribute:)
      elsif !policy.allowed?
        add_not_permitted_error_for(record, attribute:)
      end
    end

    def action_name
      @action_name ||= options.fetch(:allowed_to)
    end

    def add_missing_policy_error_for(record, attribute:)
      record.errors.add(
        attribute,
        "does not have #{action_name.to_s.inspect} action policy defined"
      )
    end

    def add_not_permitted_error_for(record, attribute:)
      record.errors.add(
        attribute,
        "action #{action_name.to_s.inspect} is not allowed"
      )
    end
  end
end
