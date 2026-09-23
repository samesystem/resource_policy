# frozen_string_literal: true

require 'spec_helper'

module ResourcePolicy
  RSpec.describe Configuration do
    subject(:config) { described_class.new }

    # The configuration only ever reads `.name` off an attribute and `.class` off a policy, so
    # standing them up as plain objects keeps the examples about the toggle itself.
    let(:attribute) { Struct.new(:name).new(:current_contract) }
    let(:policy) { Struct.new(:target).new(nil) }
    let(:record) { Struct.new(:id).new(1) }
    let(:reported) { [] }

    before { config.reporter = ->(event) { reported << event } }

    describe '#nested_protection' do
      it 'enforces by default, so a gap fails on the first test run' do
        expect(config.nested_protection).to eq(:hard)
      end

      it 'is switched by assigning a mode' do
        config.nested_protection = :soft

        expect(config).not_to be_hard
      end

      it 'accepts a string, so the mode can come straight from an env var' do
        config.nested_protection = 'soft'

        expect(config.nested_protection).to eq(:soft)
      end

      it 'refuses a mode it does not know, rather than silently enforcing nothing' do
        expect { config.nested_protection = :warn }
          .to raise_error(ArgumentError, /unknown mode :warn/)
      end
    end

    describe '#protectable?' do
      it 'treats nothing as protectable until the host app says otherwise' do
        expect(config).not_to be_protectable(record)
      end

      it 'asks the configured callable' do
        config.protectable = ->(value) { value.is_a?(record.class) }

        expect(config).to be_protectable(record)
      end
    end

    describe '#report_unprotected_nested_value' do
      def report
        config.report_unprotected_nested_value(policy: policy, attribute: attribute, value: record)
      end

      context 'when the mode is hard' do
        it 'raises, because nobody can vouch for the value' do
          expect { report }.to raise_error(Configuration::UnprotectedNestedValueError, /:current_contract/)
        end

        it 'does not report, because raising is the whole signal' do
          expect { report }.to raise_error(Configuration::UnprotectedNestedValueError) & change { reported }.by([])
        end
      end

      context 'when the mode is soft' do
        before { config.nested_protection = :soft }

        it 'reports instead of raising' do
          report

          expect(reported.map(&:attribute)).to eq([attribute])
        end

        it 'names the declaration which would fix it' do
          report

          expect(reported.first.message).to include('c.attribute(:current_contract).nested')
        end
      end
    end

    describe '#withhold_denied_nested_read?' do
      let(:nested_policy) { Struct.new(:contract).new(nil) }

      def withhold?
        config.withhold_denied_nested_read?(policy: policy, attribute: attribute, nested_policy: nested_policy)
      end

      context 'when the mode is hard' do
        it 'withholds the value' do
          expect(withhold?).to be(true)
        end
      end

      context 'when the mode is soft' do
        before { config.nested_protection = :soft }

        it 'hands the value over, so switching the mode on changes nothing for callers' do
          expect(withhold?).to be(false)
        end

        it 'reports which policy denied the read' do
          withhold?

          expect(reported.map(&:nested_policy)).to eq([nested_policy])
        end
      end
    end

    describe '.configure' do
      after { ResourcePolicy.instance_variable_set(:@config, nil) }

      it 'yields the global configuration' do
        ResourcePolicy.configure { |c| c.nested_protection = :soft }

        expect(ResourcePolicy.config.nested_protection).to eq(:soft)
      end

      it 'returns the configuration it configured' do
        expect(ResourcePolicy.configure { |c| c.nested_protection = :soft }).to be(ResourcePolicy.config)
      end
    end
  end
end
