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

      context 'when action does not exist' do
        it { is_expected.to be_nil }
      end

      context 'when action exists' do
        before do
          policy_model.actions_policy { |c| c.allowed_to(action_name) }
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
          policy_model.attributes_policy do |c|
            c.attribute(attribute_name).allowed(:read)
          end
        end

        it 'returns correct attribute' do
          expect(attribute.name).to eq attribute_name
        end
      end
    end
  end
end
