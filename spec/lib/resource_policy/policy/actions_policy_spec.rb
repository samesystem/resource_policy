# frozen_string_literal: true

require 'spec_helper'

module ResourcePolicy::Policy
  RSpec.describe ActionsPolicy do
    let(:model) do
      Class.new do
        include ResourcePolicy::Policy

        policy do |c|
          c.action(:create).allowed(if: :yes)
          c.action(:failing).allowed(if: :no)
        end

        def yes
          true
        end

        def no
          false
        end
      end
    end

    describe '#actions_policy' do
      let(:actions_policy) { model.new.actions_policy }

      context 'when action conditions are passing' do
        it 'marks actions as allowed ' do
          expect(actions_policy.create).to be_allowed
        end
      end

      context 'when action conditions are failing' do
        it 'marks actions as not allowed ' do
          expect(actions_policy.failing).not_to be_allowed
        end
      end
    end
  end
end
