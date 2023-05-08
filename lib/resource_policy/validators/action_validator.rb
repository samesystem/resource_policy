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
      validation_options = validation_options_for(record, default_attribute, policy)

      validate_action_policy(**validation_options)
    end

    private

    def validation_options_for(record, default_attribute, policy)
      attribute = fetch_option_value(:as, record: record) { default_attribute }
      action_name = fetch_option_value(:allowed_to, record: record)
      action_policy = policy.action(action_name)

      {
        policy: action_policy,
        record: record,
        attribute: attribute,
        action_name: action_name
      }
    end

    def validate_action_policy(policy:, record:, attribute:, action_name:)
      if policy.nil?
        add_missing_policy_error_for(record, attribute, action_name)
      elsif !policy.allowed?
        add_not_permitted_error_for(record, attribute, action_name)
      end
    end

    def add_missing_policy_error_for(record, attribute, action_name)
      record.errors.add(
        attribute,
        "does not have #{action_name.to_s.inspect} action policy defined"
      )
    end

    def add_not_permitted_error_for(record, attribute, action_name)
      record.errors.add(
        attribute,
        "action #{action_name.to_s.inspect} is not allowed"
      )
    end

    def fetch_option_value(key, record:, &block)
      value = options.fetch(key, &block)

      return record.instance_exec(&value) if value.is_a?(Proc)

      value
    end
  end
end
