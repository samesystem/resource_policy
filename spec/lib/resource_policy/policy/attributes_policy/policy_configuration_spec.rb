# frozen_string_literal: true

require 'spec_helper'

module ResourcePolicy::Policy
  # RSpec.describe PolicyConfiguration do
  #   subject(:policy_configuration) { described_class.new }

  #   describe '#allowed_to' do
  #     let(:attribute) { policy_configuration.attribute(:something) }

  #     before do
  #       policy_configuration.allowed_to(:read, if: :readable?)
  #       policy_configuration.attribute(:something).allowed(:read, :write)
  #     end

  #     it 'adds conditions to attributes which are allowed to the same action' do
  #       expect(attribute.conditions_for(:read)).to eq([:readable?])
  #     end

  #     it 'does not add condition to other attribute actions' do
  #       expect(attribute.conditions_for(:write)).to be_empty
  #     end

  #     context 'when attribute settings includes "if" part' do
  #       before do
  #         attribute.allowed(:read, if: :attribute_readable?)
  #       end

  #       it 'includes conditions both global group conditions and attribute conditions' do
  #         expect(attribute.conditions_for(:read)).to match_array(%i[readable? attribute_readable?])
  #       end
  #     end

  #     context 'when attribute is in the group' do
  #       let(:attribute) { policy_configuration.attribute(:group_attribute) }

  #       before do
  #         policy_configuration.group(:group_readable?) do |g|
  #           g.attribute(:group_attribute).allowed(:read, :write)
  #         end
  #       end

  #       it 'includes conditions both global group conditions and group conditions' do
  #         expect(attribute.conditions_for(:read)).to match_array(%i[readable? group_readable?])
  #       end
  #     end
  #   end

  #   describe '#attribute' do
  #     subject(:attribute) do
  #       policy_configuration.attribute(:something).tap do |attribute|
  #         attribute.allowed(*allowed_actions, **conditions) if allowed_actions && !allowed_actions.empty?
  #       end
  #     end

  #     let(:allowed_actions) { :read }
  #     let(:conditions) { { if: :readable? } }

  #     context 'when attribute has settings' do
  #       context 'when settings includes "if" part' do
  #         it 'adds attribute to attributes list' do
  #           expect { attribute }.to change { policy_configuration.attributes.size }.by(1)
  #         end
  #       end

  #       context 'when settings does not include "if" part' do
  #         let(:conditions) { {} }

  #         it 'adds attribute to attributes list' do
  #           expect { attribute }.to change { policy_configuration.attributes.size }.by(1)
  #         end
  #       end
  #     end

  #     context 'when attribute does not have settings' do
  #       let(:allowed_actions) { nil }
  #       let(:conditions) { {} }

  #       it 'does not add attribute to attributes list' do
  #         expect { attribute }.not_to change { policy_configuration.attributes.size }
  #       end
  #     end
  #   end

  #   describe '#group' do
  #     before do
  #       policy_configuration.group(:writable?) do |g|
  #         g.attribute(:writable_attribute).allowed(:write)
  #         g.attribute(:readable_and_writable_attribute).allowed(:write)
  #         g.attribute(:attribute_with_extra_if).allowed(:write, if: :admin?)
  #       end

  #       policy_configuration.group(:readable?) do |g|
  #         g.attribute(:readable_and_writable_attribute).allowed(:read)
  #       end
  #     end

  #     let(:attribute_name) { :writable_attribute }
  #     let(:attribute) { policy_configuration.attribute(attribute_name) }

  #     context 'when field does not have extra "if" conditions' do
  #       it 'sets conditions correctly' do
  #         expect(attribute.conditions_for(:write)).to match_array(%i[writable?])
  #       end
  #     end

  #     context 'when field has extra "if" conditions' do
  #       let(:attribute_name) { :attribute_with_extra_if }

  #       it 'joins conditions from group and "if" part' do
  #         expect(attribute.conditions_for(:write)).to match_array(%i[admin? writable?])
  #       end
  #     end

  #     context 'when same attribute is included in multiple groups' do
  #       let(:attribute_name) { :readable_and_writable_attribute }

  #       it 'includes conditions from all groups', :aggregate_failures do
  #         expect(attribute.conditions_for(:write)).to match_array(%i[writable?])
  #         expect(attribute.conditions_for(:read)).to match_array(%i[readable?])
  #       end
  #     end
  #   end
  # end
end
