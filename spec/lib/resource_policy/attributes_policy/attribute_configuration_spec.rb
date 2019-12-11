# frozen_string_literal: true

require 'spec_helper'

module ResourcePolicy::AttributesPolicy
  RSpec.describe AttributeConfiguration do
    subject(:attribute_configuration) { described_class.new(:attr, attributes_policy: attributes_policy) }

    let(:attributes_policy) { PolicyConfiguration.new }

    describe '#allowed' do
      subject(:allowed) { attribute_configuration.allowed(:read) }

      it 'returns itself' do
        expect(allowed).to be attribute_configuration
      end

      context 'when multiple access levels are given' do
        subject(:allowed) { attribute_configuration.allowed(:read, :write, if: :allowed) }

        it 'sets conditions for all levels' do
          expect { allowed }
            .to change { attribute_configuration.conditions_for(:read) }
            .and change { attribute_configuration.conditions_for(:write) }
        end
      end
    end

    describe '#configured?' do
      let(:allowed) { attribute_configuration.allowed(:read) }

      context 'when #allowed action is called' do
        it 'marks attribute as configured' do
          expect { allowed }.to change(attribute_configuration, :configured?).from(false).to(true)
        end
      end
    end

    describe '#defined_actions' do
      subject(:defined_actions) { attribute_configuration.defined_actions }

      before do
        attribute_configuration.allowed(:read)
      end

      it 'returns which actions where allowed' do
        expect(defined_actions).to match_array(%i[read])
      end
    end

    describe '#merge' do
      subject(:merge) { attribute_configuration.merge(other_attribute_configuration) }

      let(:attribute_configuration) do
        described_class.new(:attr, attributes_policy: attributes_policy).allowed(:write, if: :monday?)
      end

      let(:other_attribute_configuration) do
        described_class.new(:attr, attributes_policy: attributes_policy).allowed(:write, if: :sunday?)
      end

      it 'does not modify initial attribute config' do
        expect { merge }.not_to change { attribute_configuration.conditions_for(:write) }
      end

      it 'does not modify merge attribute config' do
        expect { merge }.not_to change { other_attribute_configuration.conditions_for(:write) }
      end

      it 'returns new config with merged conditions' do
        expect(merge.conditions_for(:write)).to match_array(%i[sunday? monday?])
      end
    end
  end
end
