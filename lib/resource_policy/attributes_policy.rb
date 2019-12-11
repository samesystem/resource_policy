# frozen_string_literal: true

module ResourcePolicy
  # Allows to define fields policy using configuration block.
  #
  # Usage example:
  #
  # class SomeModelPolicy
  #   include ResourcePolicy::AttributesPolicy
  #
  #   attributes_policy do |c|
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
    require 'resource_policy/attributes_policy/policy_configuration'
    require 'resource_policy/attributes_policy/attributes_policy_model'

    # Used for defining class methods
    module ClassMethods
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@attributes_policy, attributes_policy.dup)
      end

      def attributes_policy
        @attributes_policy ||= PolicyConfiguration.new

        yield(@attributes_policy) if block_given?

        @attributes_policy
      end
    end

    def self.included(base)
      base.extend(AttributesPolicy::ClassMethods)
    end

    def attributes_policy
      @attributes_policy ||= AttributesPolicyModel.new(self)
    end
  end
end
