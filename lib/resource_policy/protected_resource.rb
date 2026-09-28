# frozen_string_literal: true

module ResourcePolicy
  # Generates resource which has same attributes as policy target,
  # but returns `nil` when attribute in not readable according to policy.
  #
  # A protected resource never hands out a raw record: a value which is itself guarded by a
  # policy comes back as that policy's own protected resource, so nested reads run nested rules
  # without every call site having to remember to ask.
  class ProtectedResource
    # `nested` marks a resource the gem wrapped on the caller's behalf rather than one the
    # caller asked for. The two answer a denied attribute differently: nilling it is the whole
    # contract of a resource you asked for, but on a nested one it is new behaviour which a
    # `.nested` declaration would otherwise introduce the moment it was added - so on `:soft`
    # that is reported and the value still handed over.
    def initialize(policy, nested: false)
      @policy = policy
      @nested = nested
    end

    def method_missing(method_name, *args)
      return super unless target_respond_to?(method_name, *args)

      attribute = policy.attribute(method_name)
      return denied(attribute, method_name, args) unless attribute.readable?

      protect(attribute, policy_target.public_send(method_name, *args))
    end

    def respond_to_missing?(*args)
      target_respond_to?(*args) || super
    end

    private

    attr_reader :policy, :nested

    def denied(attribute, method_name, args)
      return nil unless nested

      withhold = ResourcePolicy.config.withhold_denied_nested_attribute?(
        policy: policy, attribute: attribute
      )
      return nil if withhold

      protect(attribute, policy_target.public_send(method_name, *args))
    end

    def protect(attribute, value)
      return value if value.nil?
      return value if attribute.unprotected?
      return protect_collection(attribute, value) if collection?(value)

      nested_policy = attribute.nested_policy_for(value)
      return protect_nested(attribute, nested_policy) if nested_policy
      return value unless ResourcePolicy.config.protectable_class?(value.class)

      # Raises in `:hard`. In `:soft` the warning is the whole signal and the data still flows,
      # so an app mid-migration keeps working.
      ResourcePolicy.config.report_unprotected_nested_value(
        policy: policy, attribute: attribute, value_class: value.class
      )
      value
    end

    # A nested object the viewer may not read at all is withheld entirely on `:hard`, rather
    # than handed out as a proxy whose every attribute answers nil. On `:soft` it is reported
    # and still handed over, so switching the mode on never changes what a caller sees.
    def protect_nested(attribute, nested_policy)
      return nested_resource(nested_policy) if readable_policy?(nested_policy)

      withhold = ResourcePolicy.config.withhold_denied_nested_read?(
        policy: policy, attribute: attribute, nested_policy: nested_policy
      )
      return nil if withhold

      nested_resource(nested_policy)
    end

    def nested_resource(nested_policy)
      self.class.new(nested_policy, nested: true)
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
      # Wrapping items is the only case which has to give up the relation. `filter_map` drops
      # the items `:hard` withholds; on `:soft` nothing is withheld, so nothing is dropped.
      return collection.filter_map { |item| protect(attribute, item) } if attribute.nested?

      item_class = collection_item_class(collection)
      return collection if item_class.nil?
      return collection unless ResourcePolicy.config.protectable_class?(item_class)

      ResourcePolicy.config.report_unprotected_nested_value(
        policy: policy, attribute: attribute, value_class: item_class
      )
      collection
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
