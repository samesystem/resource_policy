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

      def protect(target, **policy_options)
        wrapper.new(target, policy_class: self, policy_options: policy_options)
      end

      def wrapper
        @wrapper ||= begin
          policy_class = self

          Class.new(PolicyProtector) do
            policy(policy_class)
          end
        end
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
