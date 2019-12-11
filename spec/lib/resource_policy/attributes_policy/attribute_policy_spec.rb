# frozen_string_literal: true

require 'spec_helper'

module ResourcePolicy::AttributesPolicy
  RSpec.describe AttributePolicy do
    subject(:attribute_policy) { described_class.new(attribute_config, policy: policy) }

    let(:attributes_policy) { PolicyConfiguration.new }
    let(:policy) do
      # rubocop:disable RSpec/VerifiedDoubles
      double(
        'Policy',
        returns_true: true,
        also_returns_true: true,
        returns_false: false
      )
      # rubocop:enable RSpec/VerifiedDoubles
    end

    let(:attribute_config) do
      AttributeConfiguration.new(:attr, attributes_policy: attributes_policy)
    end

    describe '#allowed_to?' do
      let(:access_level) { :do_something }

      context 'when attribute does not have "write" access specified' do
        it { is_expected.not_to be_allowed_to(access_level) }
      end

      context 'when attribute has expected access level without conditions' do
        before do
          attribute_config.allowed(access_level)
        end

        it { is_expected.to be_allowed_to(access_level) }
      end

      context 'when all access level conditions are met' do
        before do
          attribute_config.allowed(access_level, if: %i[returns_true also_returns_true])
        end

        it { is_expected.to be_allowed_to(access_level) }
      end

      context 'when some conditions can not be satisfied' do
        before do
          attribute_config.allowed(:write, if: %i[returns_true also_returns_true returns_false])
        end

        it { is_expected.not_to be_allowed_to(access_level) }
      end
    end

    describe '#readable?' do
      context 'when attribute does not have "read" access level' do
        it { is_expected.not_to be_readable }
      end

      context 'when attribute has "read" access level' do
        before do
          attribute_config.allowed(:read)
        end

        it { is_expected.to be_readable }
      end
    end

    describe '#writable?' do
      context 'when attribute does not have "write" access level' do
        it { is_expected.not_to be_writable }
      end

      context 'when attribute has "write" access level' do
        before do
          attribute_config.allowed(:write)
        end

        it { is_expected.to be_writable }
      end
    end
  end
end
