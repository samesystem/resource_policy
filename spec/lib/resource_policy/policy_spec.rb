# frozen_string_literal: true

require 'spec_helper'

module ResourcePolicy
  RSpec.describe Policy do
    subject(:policy) { policy_model.new }

    let(:policy_model) do
      Class.new do
        include ResourcePolicy::Policy
      end
    end

    describe '#action' do
      subject(:action) { policy.action(action_name) }

      let(:action_name) { :create }

      context 'when action is not marked as "allowed"' do
        it { is_expected.to be_nil }
      end

      context 'when action exists' do
        before do
          policy_model.policy { |c| c.action(action_name).allowed }
        end

        it 'returns correct action' do
          expect(action.name).to eq action_name
        end
      end
    end

    describe '#attribute' do
      subject(:attribute) { policy.attribute(attribute_name) }

      let(:attribute_name) { :something }

      context 'when attribute does not exist' do
        it { is_expected.to be_nil }
      end

      context 'when attribute exists' do
        before do
          policy_model.policy do |c|
            c.attribute(attribute_name).allowed(:read)
          end
        end

        it 'returns correct attribute' do
          expect(attribute.name).to eq attribute_name
        end
      end
    end

    describe '#protected_resource' do
      subject(:protected_resource) { policy.protected_resource }

      it { is_expected.to be_a(ResourcePolicy::ProtectedResource) }
    end

    describe '#policy_target' do
      let(:policy_target) { policy_model.new('something').policy_target }

      context 'when policy class has parent with custom initialize method' do
        let(:policy_model) do
          Struct.new(:something) do
            include ResourcePolicy::Policy

            policy.policy_target(:something)
          end
        end

        it 'sets first initialize argument as policy_target' do
          expect(policy_target).to eq('something')
        end
      end

      context 'when policy class has parent with default initialize method' do
        let(:policy_model) do
          Class.new do
            include ResourcePolicy::Policy

            policy.policy_target(:something)

            attr_reader :something

            def initialize(something)
              @something = something
            end
          end
        end

        it 'sets first initialize argument as policy_target' do
          expect(policy_target).to eq('something')
        end
      end
    end
  end
end
