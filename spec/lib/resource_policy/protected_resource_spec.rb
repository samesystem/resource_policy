# frozen_string_literal: true

require 'spec_helper'

module ResourcePolicy
  RSpec.describe ProtectedResource do
    subject(:protected_resource) { described_class.new(policy) }

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

    let(:policy) { policy_class.new(target, viewer) }
    let(:initial_target_class) { Struct.new(:some_attribute) }
    let(:target_class) { initial_target_class }
    let(:target) { target_class.new('Some value') }

    let(:viewer) do
      double('Viewer', reader?: true, writer?: true) # rubocop:disable RSpec/VerifiedDoubles
    end

    describe '#method_missing' do
      subject(:method_missing_value) { protected_resource.some_attribute }

      context 'when attribute is allowed to read' do
        it { is_expected.not_to be_nil }
      end

      context 'when attribute is not allowed to read' do
        before do
          allow(viewer).to receive(:reader?).and_return(false)
        end

        it { is_expected.to be_nil }
      end
    end

    describe '#respond_to?' do
      context 'when method exists on target' do
        context 'when attribute is not specified on policy' do
          let(:target_class) do
            initial_target_class.send(:define_method, :some_non_policy_attribute) { true }
            initial_target_class
          end

          it 'returns false' do
            expect(protected_resource).not_to be_respond_to(:some_non_policy_attribute)
          end
        end

        context 'when attribute is specified on policy' do
          it 'returns true' do
            expect(protected_resource).to be_respond_to(:some_attribute)
          end
        end
      end

      context 'when method does not exist on target' do
        it 'returns false' do
          expect(protected_resource).not_to be_respond_to(:non_existing_method)
        end
      end
    end
  end
end
