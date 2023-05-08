# frozen_string_literal: true

require 'spec_helper'
require 'active_model'
require 'resource_policy/rails'

RSpec.describe ResourcePolicy::ActionValidator do
  describe '#validate_each' do
    # Validator#validate_each will be called when we call record#valid?.
    let(:record_class) do
      action = action_type

      Struct.new(:policy) do
        include ActiveModel::Validations
        validates :policy, 'resource_policy/action': { allowed_to: action, as: :user }

        def custom_allowed_to
          :create
        end
      end
    end

    let(:policy_class) do
      Class.new do
        include ResourcePolicy::Policy

        policy do |c|
          c.action(:create).allowed(if: :action_allowed)
        end

        attr_reader :action_allowed

        def initialize(action_allowed:)
          @action_allowed = action_allowed
        end
      end
    end

    let(:record) { record_class.new(policy) }
    let(:policy) { policy_class.new(action_allowed: is_action_allowed) }
    let(:action_type) { :create }
    let(:is_action_allowed) { true }

    context 'when action is allowed by policy' do
      it 'keeps record valid' do
        expect { record.valid? }.not_to change(record.errors, :count)
      end
    end

    context 'when action is not allowed by policy' do
      let(:is_action_allowed) { false }

      it 'adds errors' do
        expect(record).not_to be_valid
        expect(record.errors.messages).to eq(user: ['action "create" is not allowed'])
      end
    end

    context 'when action does not exist' do
      let(:action_type) { :does_not_exist }

      it 'adds errors' do
        record.valid?
        expect(record.errors.messages)
          .to eq(user: ['does not have "does_not_exist" action policy defined'])
      end
    end

    context 'when "allowed_to" is a proc' do
      let(:action_type) { -> { custom_allowed_to } }

      it 'keeps record valid' do
        expect { record.valid? }.not_to change(record.errors, :count)
      end
    end
  end
end
