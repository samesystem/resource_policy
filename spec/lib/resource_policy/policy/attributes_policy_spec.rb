# frozen_string_literal: true

require 'spec_helper'

module ResourcePolicy::Policy
  RSpec.describe AttributesPolicy do
    subject(:policy_instance) { policy_class.new(target, viewer) }

    let(:policy_class) do
      Struct.new(:target, :viewer) do
        include ResourcePolicy::Policy

        policy do |c|
          c.policy_target :target
          c.attribute(:some_attribute)
           .allowed(:read, if: :readable?)
           .allowed(:write, if: :writable?)
        end

        private

        def readable?
          viewer.reader?
        end

        def writable?
          viewer.writer?
        end
      end
    end

    let(:target) { nil }
    let(:viewer) do
      double('Viewer', reader?: true, writer?: true) # rubocop:disable RSpec/VerifiedDoubles
    end

    let(:attributes_policy) { policy_instance.attributes_policy }

    describe '#attributes_policy' do
      it 'returns attribute policy based on conditions' do
        expect(attributes_policy.some_attribute)
          .to be_readable
          .and be_writable
      end

      context 'when attribute is declared without allowed actions' do
        before { policy_class.policy { |c| c.attribute(:undecided_attribute) } }

        it 'does not respond to the attribute' do
          expect(attributes_policy).not_to respond_to(:undecided_attribute)
        end

        it 'raises NoMethodError for the attribute' do
          expect { attributes_policy.undecided_attribute }
            .to raise_error(NoMethodError) { |error| expect(error.name).to eq(:undecided_attribute) }
        end
      end

      context 'when policy gets a new attribute after first use' do
        before do
          attributes_policy.respond_to?(:late_attribute)
          policy_class.policy { |c| c.attribute(:late_attribute).allowed(:read) }
        end

        it 'returns attribute policy for the new attribute' do
          expect(attributes_policy.late_attribute)
            .to have_attributes(name: :late_attribute, readable?: true, writable?: false)
        end
      end
    end

    describe '#all_allowed_to' do
      before { policy_class.policy { |c| c.attribute(:read_only_attribute).allowed(:read) } }

      it 'returns readable attribute policies in definition order' do
        expect(attributes_policy.all_allowed_to(:read).map(&:name)).to eq(%i[some_attribute read_only_attribute])
      end

      it 'returns writable attribute policies' do
        expect(attributes_policy.all_allowed_to(:write).map(&:name)).to eq(%i[some_attribute])
      end

      it 'returns the same attribute policies as direct access' do
        expect(attributes_policy.all_allowed_to(:write).first).to be(attributes_policy.some_attribute)
      end
    end
  end
end
