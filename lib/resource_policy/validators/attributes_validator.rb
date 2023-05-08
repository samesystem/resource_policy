# frozen_string_literal: true

# Validates attributes hash.
#
# Available options:
#
#   * `:apply_to` (required) - hash which needs to be validated using policy.
#   * `:allowed_to` (required) - access level which we need to check. In most cases it's `:read` or `:write`.
#
# Usage example:
#
#   class MyClass
#     include ActiveModel::Validations
#     validates :some_policy, 'resource_policy/attributes': { apply_to: :some_params, allowed_to: :write }
#
#     def some_policy
#       SomePolicy.new
#     end
#
#     def some_params
#       { foo: :foo, bar: :bar }
#     end
#   end
#
module ResourcePolicy
  class AttributesValidator < ActiveModel::EachValidator
    def validate_each(record, _attribute, policy)
      hash_value = hash_value_for(record)

      hash_value.each_key do |hash_attribute|
        validate_attribute_policy(
          policy.attribute(hash_attribute),
          record: record,
          hash_attribute: hash_attribute
        )
      end
    end

    private

    def validate_attribute_policy(attribute_policy, record:, hash_attribute:)
      if attribute_policy.nil?
        add_missing_policy_error_for(record, hash_attribute)
      elsif !attribute_policy.allowed_to?(access_level)
        add_not_permitted_error_for(record, hash_attribute)
      end
    end

    def access_level
      @access_level ||= options.fetch(:allowed_to)
    end

    def hash_value_for(record)
      record.send(options.fetch(:apply_to))
    end

    def add_missing_policy_error_for(record, attribute)
      record.errors.add(attribute, 'does not have attribute policy defined')
    end

    def add_not_permitted_error_for(record, attribute)
      record.errors.add(
        attribute,
        "attribute action #{access_level.to_s.inspect} is not allowed"
      )
    end
  end
end
