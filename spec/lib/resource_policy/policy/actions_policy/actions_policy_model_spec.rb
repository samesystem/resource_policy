# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::ResourcePolicy:: Policy::ActionsPolicy::ActionsPolicyModel do
  subject(:actions_policy_model) { described_class.new(model_instance) }

  let(:policy_model) do
    Class.new do
      include ResourcePolicy::Policy

      policy do |c|
        c.action(:create).allowed
        c.action(:read).allowed
        c.action(:forbidden_action).allowed(if: :force_not_allowed)
      end

      def force_not_allowed
        false
      end
    end
  end

  let(:model_instance) { policy_model.new }

  describe '#actions' do
    subject(:actions) { actions_policy_model.actions }

    it 'returns actions' do
      expect(actions).to all be_a(::ResourcePolicy::Policy::ActionsPolicy::ActionPolicy)
    end

    it 'returns actions with correct names' do
      expect(actions.map(&:name)).to contain_exactly(:create, :read, :forbidden_action)
    end
  end

  describe '#allowed_action_names' do
    subject(:allowed_action_names) { actions_policy_model.allowed_action_names }

    it 'returns allowed actions' do
      expect(allowed_action_names).to contain_exactly(:create, :read)
    end
  end
end
