# frozen_string_literal: true

module ResourcePolicy
  module Policy
    # Allows to define fields policy using configuration block.
    #
    # Usage example:
    #
    # class SomeModelPolicy
    #   include ResourcePolicy::AttributesPolicy
    #
    #   policy do |c|
    #     c.attribute(:some_name)
    #       .allowed(:read, if: :readable?)
    #       .allowed(:write, if: :writable?)
    #
    #     c.group(:current_user_is_admin?) do |g|
    #       g.attribute(:password).allowed(:write)
    #     end
    #   end
    #
    #   def current_user_is_admin?
    #      current_user.admin?
    #   end
    #   ...
    # end
    #
    module AttributesPolicy
      require 'resource_policy/policy/attributes_policy/attributes_policy_model'

      # Used for defining class methods
      module ClassMethods
        def inherited(subclass)
          super
          subclass.instance_variable_set(:@attributes_policy, attributes_policy.dup)
        end
      end

      def self.included(base)
        base.extend(AttributesPolicy::ClassMethods)
      end

      def protected_resource
        @protected_resource ||= ProtectedResource.new(self)
      end

      def action(name)
        actions_policy.public_send(name) if actions_policy.respond_to?(name)
      end

      def attribute(name)
        attributes_policy.public_send(name) if attributes_policy.respond_to?(name)
      end

      def policy_target
        send(self.class.policy.policy_target)
      end

      def attributes_policy
        @attributes_policy ||= AttributesPolicyModel.new(self)
      end

      private

      def resource_policy_initialize(*args)
        @policy_target = args.first
      end
    end
  end
end
