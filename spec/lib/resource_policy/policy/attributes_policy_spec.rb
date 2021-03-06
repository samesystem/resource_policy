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

    describe '#attributes_policy' do
      let(:attributes_policy) { policy_instance.attributes_policy }

      it 'returns attribute policy based on conditions' do
        expect(attributes_policy.some_attribute)
          .to be_readable
          .and be_writable
      end
    end
  end
end
