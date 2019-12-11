# frozen_string_literal: true

module ResourcePolicy
  module AttributesPolicy
    # @private
    #
    # Allows to easier define protector class for each policy.
    class PolicyProtector
      def self.policy(policy_class)
        policy_class.attributes_policy.attributes.each do |attribute_name, _|
          define_method attribute_name do |*args|
            if policy.attributes_policy.public_send(attribute_name).readable?
              target_object.public_send(attribute_name, *args)
            end
          end
        end
      end

      attr_reader :policy

      def initialize(target, policy_class:, policy_args:)
        @target_object = target
        @policy = policy_class.new(target, *policy_args)
      end

      protected

      attr_reader :target_object
    end
  end
end
