# frozen_string_literal: true

require 'spec_helper'

module ResourcePolicy::Policy
  RSpec.describe PolicyConfiguration do
    subject(:policy_configuration) { described_class.new }

    describe '#attribute' do
      subject(:attribute) do
        policy_configuration.attribute(:something).tap do |attribute|
          attribute.allowed(*allowed_actions, **conditions) if allowed_actions && !allowed_actions.empty?
        end
      end

      let(:allowed_actions) { :read }
      let(:conditions) { { if: :readable? } }

      context 'when attribute has settings' do
        context 'when settings includes "if" part' do
          it 'adds attribute to attributes list' do
            expect { attribute }.to change { policy_configuration.attributes.size }.by(1)
          end
        end

        context 'when settings does not include "if" part' do
          let(:conditions) { {} }

          it 'adds attribute to attributes list' do
            expect { attribute }.to change { policy_configuration.attributes.size }.by(1)
          end
        end
      end

      context 'when attribute does not have settings' do
        let(:allowed_actions) { nil }
        let(:conditions) { {} }

        it 'does not add attribute to attributes list' do
          expect { attribute }.not_to change { policy_configuration.attributes.size }
        end
      end
    end

    describe '#action' do
      let(:action) { policy_configuration.action(action_name) }
      let(:action_name) { :read }

      before do
        policy_configuration.action(action_name).allowed(if: :readable?)
      end

      it 'adds conditions to listed actions' do
        expect(policy_configuration.action(:read).conditions).to eq([:readable?])
      end

      it 'adds action to actions list' do
        expect(policy_configuration.actions.keys).to match_array([:read])
      end

      it 'does not add condition to other actions' do
        expect(policy_configuration.action(:write).conditions).to be_empty
      end

      context 'when actions is in the group' do
        before do
          policy_configuration.group(:group_writable?) do |g|
            g.action(:write).allowed(if: :writable?)
          end
        end

        it 'includes conditions from group and from local settings' do
          expect(policy_configuration.action(:write).conditions)
            .to match_array(%i[writable? group_writable?])
        end
      end
    end

    describe '#group' do
      subject(:group) { policy_configuration_with_group }

      let(:policy_configuration_with_group) do
        policy_configuration.group(:group_readable?) do |g|
          g.action(:read).allowed
        end
      end

      context 'when defining action in a group' do
        context 'when defining same action in different groups' do
          subject(:group) do
            policy_configuration_with_group.group(:group2_readable?) do |g|
              g.action(:read).allowed
            end
          end

          it 'includes conditions from multiple places' do
            expect(group.action(:read).conditions).to match_array(%i[group_readable? group2_readable?])
          end
        end
      end

      context 'when defining attribute group' do
        let!(:policy_configuration_with_group) do
          policy_configuration.group(:group_readable?) do |g|
            g.attribute(:something).allowed(:read)
          end
        end

        context 'when defining same attribute but different action in other group' do
          subject(:group) do
            policy_configuration_with_group.group(:group_writable?) do |g|
              g.attribute(:something).allowed(:write)
            end
          end

          it 'updates action' do
            expect { group }
              .to change { policy_configuration.attribute(:something).defined_actions }
              .from([:read]).to(%i[read write])
          end
        end

        context 'when defining same attribute action in other group' do
          subject(:group) do
            policy_configuration_with_group.group(:group2_readable?) do |g|
              g.attribute(:something).allowed(:read)
            end
          end

          it 'updates attribute conditions' do
            conditions = group.attribute(:something).conditions_for(:read)
            expect(conditions).to match_array(%i[group_readable? group2_readable?])
          end
        end
      end
    end
  end
end
