# frozen_string_literal: true

require 'spec_helper'

module ResourcePolicy
  RSpec.describe ActionsPolicy do
    let(:model) do
      Class.new do
        include ResourcePolicy::ActionsPolicy

        actions_policy do |c|
          c.allowed_to(:create, if: :yes)
          c.allowed_to(:failing, if: :no)
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
