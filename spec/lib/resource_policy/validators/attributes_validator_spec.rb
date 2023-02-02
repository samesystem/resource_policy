# frozen_string_literal: true

require 'spec_helper'
require 'active_model'
require 'resource_policy/rails'

RSpec.describe ResourcePolicy::AttributesValidator do
  describe '#validate_each' do
    subject(:record) { record_class.new(params, policy) }

    let(:record_class) do
      required_level = access_level

      Struct.new(:params, :policy) do
        include ActiveModel::Validations
        validates :policy, 'resource_policy/attributes': { apply_to: :params, allowed_to: required_level }
      end
    end

    let(:policy_class) do
      Class.new do
        include ResourcePolicy::Policy

        policy do |c|
          c.attribute(:first_name).allowed(:write, if: :allowed)
        end

        attr_reader :allowed

        def initialize(allowed:)
          @allowed = allowed
        end
      end
    end


    let(:params) { { first_name: 'John' } }
    let(:policy) { policy_class.new(allowed: is_allowed) }
    let(:is_allowed) { true }
    let(:access_level) { :write }


    context 'when attribute matches expected access level' do
      it { is_expected.to be_valid }
    end

    context 'when attribute action is not allowed' do
      let(:is_allowed) { false }

      it 'adds errors' do
        record.valid?
        expect(record.errors.messages).to eq(first_name: ['attribute action "write" is not allowed'])
      end
    end

    context 'when attribute does not exist' do
      let(:params) { { does_not_exist: true } }

      it 'adds errors' do
        record.valid?
        expect(record.errors.messages)
          .to eq(does_not_exist: ['does not have attribute policy defined'])
      end
    end

    context 'when access level dose not exist' do
      let(:access_level) { :does_not_exist }

      it 'adds errors' do
        record.valid?
        expect(record.errors.messages)
          .to eq(first_name: ['attribute action "does_not_exist" is not allowed'])
      end
    end
  end
end
