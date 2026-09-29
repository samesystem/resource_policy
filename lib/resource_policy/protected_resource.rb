# frozen_string_literal: true

module ResourcePolicy
  # Generates resource which has same attributes as policy target,
  # but returns `nil` when attribute in not readable according to policy.
  #
  # On `:hard` a protected resource never hands out a raw record: a value which is itself
  # guarded by a policy comes back as that policy's own protected resource, so nested reads run
  # nested rules without every call site having to remember to ask.
  #
  # On `:soft` none of that happens. A `.nested` declaration is inert: the value is handed back
  # exactly as the target returned it - the same record, the same relation, still lazy, with
  # every item in it. Soft exists to be switched on in a running application without changing
  # anything a caller receives, so declarations can be written and reviewed long before the
  # behaviour they describe is turned on. What `:hard` would do instead is found by running in
  # `:hard`, not by reading soft's output.
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
      return protect_declared(attribute, value) if attribute.nested?

      report_undeclared(attribute, value.class)
      value
    end

    # A declaration says what `:hard` does. On `:soft` it is inert, so the value is handed back
    # as it came and nothing is reported: the declaration is already visible in the policy.
    def protect_declared(attribute, value)
      return value unless ResourcePolicy.config.hard?

      nested_policy = attribute.nested_policy_for(value)
      return value unless nested_policy

      protect_nested(attribute, nested_policy)
    end

    # Raises in `:hard`. In `:soft` the warning is the whole signal and the data still flows,
    # so an app mid-migration keeps working.
    def report_undeclared(attribute, value_class)
      return unless ResourcePolicy.config.protectable_class?(value_class)

      ResourcePolicy.config.report_unprotected_nested_value(
        policy: policy, attribute: attribute, value_class: value_class
      )
    end

    # Reached on `:hard` only. A nested object the viewer may not read at all is withheld
    # entirely, rather than handed out as a proxy whose every attribute answers nil.
    def protect_nested(_attribute, nested_policy)
      return nil unless readable_policy?(nested_policy)

      nested_policy.protected_resource
    end

    def readable_policy?(nested_policy)
      read_action = nested_policy.action(:read) if nested_policy.respond_to?(:action)
      return read_action.allowed? if read_action

      nested_policy.attributes_policy.all_allowed_to(:read).any?
    end

    # A collection is one decision, not one per item, and the decision is taken from the item
    # class rather than from a row. Nothing here reads an element: a declaration is a property
    # of the attribute, and the class of an unloaded relation's items is a property of the
    # relation, so a list attribute costs no query and keeps `.includes`, `.where` and the rest
    # for the callers which never needed wrapping.
    def protect_collection(attribute, collection)
      return wrap_items(attribute, collection) if attribute.nested?

      item_class = collection_item_class(collection)
      return collection if item_class.nil?
      return collection unless ResourcePolicy.config.protectable_class?(item_class)

      ResourcePolicy.config.report_unprotected_nested_value(
        policy: policy, attribute: attribute, value_class: item_class
      )
      collection
    end

    # Wrapping items is the only case which has to give up the relation, so it happens on
    # `:hard` alone: a relation handed to a caller on `:soft` is the one the target returned,
    # lazy and chainable, holding everything it held. `nil` entries survive the wrapping,
    # because only the items the viewer may not read are meant to disappear.
    def wrap_items(attribute, collection)
      return collection unless ResourcePolicy.config.hard?

      collection.each_with_object([]) do |item, wrapped|
        next wrapped << nil if item.nil?

        protected_item = protect(attribute, item)
        wrapped << protected_item unless protected_item.nil?
      end
    end

    # `klass` is what an ActiveRecord::Relation answers without loading anything, so a relation
    # is decided whether or not it holds rows. Any other enumerable is already in memory, so
    # reading its first item costs nothing - and an empty one says nothing about its contents,
    # which is the one case left where a missing declaration goes unnoticed.
    def collection_item_class(collection)
      return collection.klass if collection.respond_to?(:klass)

      collection.first&.class
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
