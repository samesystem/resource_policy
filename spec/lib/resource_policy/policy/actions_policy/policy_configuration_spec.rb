# frozen_string_literal: true

require 'spec_helper'

module ResourcePolicy::ActionsPolicy
  # RSpec.describe PolicyConfiguration do
  #   subject(:policy_configuration) { described_class.new }

  #   describe '#action' do
  #     let(:action) { policy_configuration.action(action_name) }
  #     let(:action_name) { :read }

  #     before do
  #       policy_configuration.action(action_name).allowed(if: :readable?)
  #     end

  #     it 'adds conditions to listed actions' do
  #       expect(policy_configuration.action(:read).conditions).to eq([:readable?])
  #     end

  #     it 'adds action to actions list' do
  #       expect(policy_configuration.action_names).to match_array([:read])
  #     end

  #     it 'does not add condition to other actions' do
  #       expect(policy_configuration.action(:write).conditions).to be_empty
  #     end

  #     context 'when actions is in the group' do
  #       before do
  #         policy_configuration.group(:group_writable?) do |g|
  #           g.action(:write).allowed(if: :writable?)
  #         end
  #       end

  #       it 'includes conditions from group and from local settings' do
  #         expect(policy_configuration.action(:write).conditions)
  #           .to match_array(%i[writable? group_writable?])
  #       end
  #     end
  #   end

  #   describe '#group' do
  #     subject(:group) { policy_configuration_with_group }

  #     let(:policy_configuration_with_group) do
  #       policy_configuration.group(:group_readable?) do |g|
  #         g.action(:read).allowed
  #       end
  #     end

  #     context 'when defining same action in different groups' do
  #       subject(:group) do
  #         policy_configuration_with_group.group(:group2_readable?) do |g|
  #           g.action(:read).allowed
  #         end
  #       end

  #       it 'raises error' do
  #         expect { group }.to raise_error(PolicyConfiguration::OverlappingActionError)
  #       end
  #     end
  #   end
  # end
end
