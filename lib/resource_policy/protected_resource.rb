# frozen_string_literal: true

module ResourcePolicy
  # Generates resource which has same attributes as policy target,
  # but returns `nil` when attribute in not readable according to policy.
  #
  # A protected resource never hands out a raw record: a value which is itself guarded by a
  # policy comes back as that policy's own protected resource, so nested reads run nested rules
  # without every call site having to remember to ask.
  class ProtectedResource
    def initialize(policy)
      @policy = policy
    end

    def method_missing(method_name, *args)
      return super unless target_respond_to?(method_name, *args)

      attribute = policy.attribute(method_name)
      return nil unless attribute.readable?

      protect(attribute, policy_target.public_send(method_name, *args))
    end

    def respond_to_missing?(*args)
      target_respond_to?(*args) || super
    end

    private

    attr_reader :policy

    def protect(attribute, value)
      return value if value.nil?
      return value if attribute.unprotected?
      return protect_collection(attribute, value) if collection?(value)

      nested_policy = attribute.nested_policy_for(value)
      return protect_nested(attribute, nested_policy) if nested_policy
      return value unless ResourcePolicy.config.protectable?(value)

      # Raises in `:hard`. In `:soft` the warning is the whole signal and the data still flows,
      # so an app mid-migration keeps working.
      ResourcePolicy.config.report_unprotected_nested_value(
        policy: policy, attribute: attribute, value: value
      )
      value
    end

    # A nested object the viewer may not read at all is withheld entirely on `:hard`, rather
    # than handed out as a proxy whose every attribute answers nil. On `:soft` it is reported
    # and still handed over, so switching the mode on never changes what a caller sees.
    def protect_nested(attribute, nested_policy)
      return nested_policy.protected_resource if readable_policy?(nested_policy)

      withhold = ResourcePolicy.config.withhold_denied_nested_read?(
        policy: policy, attribute: attribute, nested_policy: nested_policy
      )
      return nil if withhold

      nested_policy.protected_resource
    end

    def readable_policy?(nested_policy)
      read_action = nested_policy.action(:read) if nested_policy.respond_to?(:action)
      return read_action.allowed? if read_action

      nested_policy.attributes_policy.all_allowed_to(:read).any?
    end

    # A collection is one decision, not one per item. Mapping first would materialise an
    # ActiveRecord::Relation into an Array before any declaration has been looked at, losing
    # `.includes`, `.where` and the rest for callers which never needed wrapping at all.
    def protect_collection(attribute, collection)
      sample = collection.first
      return collection if sample.nil?

      # Wrapping items is the only case which has to give up the relation. `filter_map` drops
      # the items `:hard` withholds; on `:soft` nothing is withheld, so nothing is dropped.
      return collection.filter_map { |item| protect(attribute, item) } if attribute.nested_policy_for(sample)
      return collection unless ResourcePolicy.config.protectable?(sample)

      ResourcePolicy.config.report_unprotected_nested_value(
        policy: policy, attribute: attribute, value: sample
      )
      collection
    end

    def collection?(value)
      value.is_a?(Enumerable) && !value.is_a?(Hash) && !value.is_a?(Struct)
    end

    def target_respond_to?(method_name, *args)
      accessible_attributes.include?(method_name.to_sym) &&
        policy_target.respond_to?(method_name, *args)
    end

    def accessible_attributes
      attributes = policy.class.policy.attributes.values.select do |attribute|
        attribute.defined_action?(:read)
      end

      attributes.map(&:name)
    end

    def policy_target
      policy.policy_target
    end
  end
end
