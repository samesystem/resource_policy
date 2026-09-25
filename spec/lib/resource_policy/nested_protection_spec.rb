# frozen_string_literal: true

require 'spec_helper'

module ResourcePolicy
  RSpec.describe 'nested attribute protection' do
    subject(:protected_resource) { ProtectedResource.new(policy) }

    # Stands in for an ActiveRecord model: something the host app says must carry its own policy.
    let(:record_class) { Class.new { attr_accessor :role, :secret } }

    # Stands in for an ActiveRecord::Relation: enumerable, but carrying query methods which are
    # lost the moment anything calls `map` on it.
    let(:relation_class) do
      Class.new do
        include Enumerable

        def initialize(items)
          @items = items
        end

        def each(&block)
          @items.each(&block)
        end

        def includes(*)
          self
        end
      end
    end

    let(:contract_class) do
      Class.new(record_class) do
        def initialize(hours)
          super()
          @hours = hours
        end

        attr_reader :hours
      end
    end

    let(:contract_policy_class) do
      Struct.new(:contract, :viewer) do
        include ResourcePolicy::Policy

        policy do |c|
          c.policy_target :contract
          c.attribute(:hours).allowed(:read, if: :hours_readable?)
        end

        private

        def hours_readable?
          viewer.hours_reader?
        end
      end
    end

    let(:target_class) { Struct.new(:current_contract, :contracts, :name) }

    let(:policy_class) do
      nested_class = contract_policy_class

      Struct.new(:target, :viewer) do
        include ResourcePolicy::Policy

        policy do |c|
          c.policy_target :target
          c.attribute(:current_contract)
           .allowed(:read)
           .nested { |contract| nested_class.new(contract, viewer) }
          c.attribute(:contracts)
           .allowed(:read)
           .nested { |contract| nested_class.new(contract, viewer) }
          c.attribute(:name).allowed(:read)
        end
      end
    end

    let(:viewer) { double('Viewer', hours_reader?: true) } # rubocop:disable RSpec/VerifiedDoubles
    let(:contract) { contract_class.new(37) }
    let(:target) { target_class.new(contract, [contract], 'John') }
    let(:policy) { policy_class.new(target, viewer) }

    before do
      ResourcePolicy.config.protectable = ->(value) { value.is_a?(record_class) }
    end

    after do
      ResourcePolicy.instance_variable_set(:@config, nil)
    end

    describe 'a declared nested attribute' do
      it 'is wrapped in the nested policy proxy rather than handed out raw' do
        expect(protected_resource.current_contract).to be_a(ProtectedResource)
      end

      it 'exposes nested values the nested policy allows' do
        expect(protected_resource.current_contract.hours).to eq(37)
      end

      context 'when the nested policy allows nothing' do
        let(:viewer) { double('Viewer', hours_reader?: false) } # rubocop:disable RSpec/VerifiedDoubles

        it 'withholds the whole value on :hard, rather than a proxy answering nil to everything' do
          expect(protected_resource.current_contract).to be_nil
        end

        context 'when configured soft' do
          let(:reported) { [] }

          before do
            ResourcePolicy.config.nested_protection = :soft
            ResourcePolicy.config.reporter = ->(event) { reported << event }
          end

          it 'still hands the value over, so turning the mode on changes nothing for callers' do
            expect(protected_resource.current_contract).to be_a(ProtectedResource)
          end

          it 'warns instead, naming the attribute and the policy which denied it' do
            protected_resource.current_contract
            expect(reported.last.message).to include(':current_contract').and include('denies reading it')
          end

          it 'reports the nested policy which made the decision' do
            protected_resource.current_contract
            expect(reported.last.nested_policy).to be_a(contract_policy_class)
          end
        end
      end

      context 'when the nested policy declares a :read action' do
        let(:contract_policy_class) do
          Struct.new(:contract, :viewer) do
            include ResourcePolicy::Policy

            policy do |c|
              c.policy_target :contract
              c.action(:read).allowed(if: :readable?)
              c.attribute(:hours).allowed(:read)
            end

            private

            def readable?
              viewer.hours_reader?
            end
          end
        end

        it 'hands the value over when the action allows reading it' do
          expect(protected_resource.current_contract).to be_a(ProtectedResource)
        end

        context 'when the action denies reading it' do
          let(:viewer) { double('Viewer', hours_reader?: false) } # rubocop:disable RSpec/VerifiedDoubles

          it 'withholds the value even though its attributes would allow the read' do
            expect(protected_resource.current_contract).to be_nil
          end

          context 'when configured soft' do
            before do
              ResourcePolicy.config.nested_protection = :soft
              ResourcePolicy.config.reporter = ->(_event) {}
            end

            it 'hands it over and warns' do
              expect(protected_resource.current_contract).to be_a(ProtectedResource)
            end
          end
        end
      end

      context 'when the value is a collection' do
        it 'wraps every item' do
          expect(protected_resource.contracts).to all(be_a(ProtectedResource))
        end

        it 'keeps nested values reachable' do
          expect(protected_resource.contracts.map(&:hours)).to eq([37])
        end

        context 'when the nested policy allows nothing' do
          let(:viewer) { double('Viewer', hours_reader?: false) } # rubocop:disable RSpec/VerifiedDoubles

          it 'drops the withheld items rather than padding the collection with nils' do
            expect(protected_resource.contracts).to eq([])
          end

          context 'when configured soft' do
            let(:reported) { [] }

            before do
              ResourcePolicy.config.nested_protection = :soft
              ResourcePolicy.config.reporter = ->(event) { reported << event }
            end

            it 'keeps every item, because soft withholds nothing' do
              expect(protected_resource.contracts).to all(be_a(ProtectedResource))
            end

            it 'warns once per withheld item' do
              protected_resource.contracts
              expect(reported.size).to eq(1)
            end
          end
        end
      end

      context 'when the value is nil' do
        let(:contract) { nil }

        it 'stays nil' do
          expect(protected_resource.current_contract).to be_nil
        end
      end
    end

    describe 'a value which needs no policy' do
      it 'is returned untouched' do
        expect(protected_resource.name).to eq('John')
      end
    end

    describe 'an undeclared record' do
      let(:policy_class) do
        Struct.new(:target, :viewer) do
          include ResourcePolicy::Policy

          policy do |c|
            c.policy_target :target
            c.attribute(:current_contract).allowed(:read)
          end
        end
      end

      it 'raises in the default hard mode, naming the attribute' do
        expect { protected_resource.current_contract }
          .to raise_error(Configuration::UnprotectedNestedValueError, /:current_contract/)
      end

      it 'suggests the declaration to add' do
        expect { protected_resource.current_contract }
          .to raise_error(Configuration::UnprotectedNestedValueError, /\.nested/)
      end

      context 'when configured soft' do
        let(:reported) { [] }

        before do
          ResourcePolicy.config.nested_protection = :soft
          ResourcePolicy.config.reporter = ->(event) { reported << event }
        end

        it 'still returns the value, so production keeps working' do
          expect(protected_resource.current_contract).to be(contract)
        end

        it 'reports the attribute it could not vouch for' do
          protected_resource.current_contract
          expect(reported.map { |event| event.attribute.name }).to eq([:current_contract])
        end
      end

      context 'when the attribute is explicitly opted out' do
        let(:policy_class) do
          Struct.new(:target, :viewer) do
            include ResourcePolicy::Policy

            policy do |c|
              c.policy_target :target
              c.attribute(:current_contract).allowed(:read).unprotected(because: 'value object')
            end
          end
        end

        it 'is returned untouched' do
          expect(protected_resource.current_contract).to be(contract)
        end
      end
    end

    describe 'a relation-backed collection' do
      let(:relation) { relation_class.new([contract]) }
      let(:target) { target_class.new(contract, relation, 'John') }

      context 'when the attribute is opted out' do
        let(:policy_class) do
          Struct.new(:target, :viewer) do
            include ResourcePolicy::Policy

            policy do |c|
              c.policy_target :target
              c.attribute(:contracts).allowed(:read).unprotected(because: 'checked elsewhere')
            end
          end
        end

        it 'keeps the relation, so callers can still chain query methods' do
          expect(protected_resource.contracts).to respond_to(:includes)
        end
      end

      context 'when the attribute is undeclared and the mode is soft' do
        let(:policy_class) do
          Struct.new(:target, :viewer) do
            include ResourcePolicy::Policy

            policy do |c|
              c.policy_target :target
              c.attribute(:contracts).allowed(:read)
            end
          end
        end

        before do
          ResourcePolicy.config.nested_protection = :soft
          ResourcePolicy.config.reporter = ->(_event) {}
        end

        it 'keeps the relation rather than flattening it into an Array' do
          expect(protected_resource.contracts).to respond_to(:includes)
        end
      end

      context 'when the attribute is undeclared and the mode is hard' do
        let(:policy_class) do
          Struct.new(:target, :viewer) do
            include ResourcePolicy::Policy

            policy do |c|
              c.policy_target :target
              c.attribute(:contracts).allowed(:read)
            end
          end
        end

        it 'raises once for the collection, naming the item class' do
          expect { protected_resource.contracts }
            .to raise_error(Configuration::UnprotectedNestedValueError, /:contracts/)
        end
      end

      context 'when the collection is empty' do
        let(:relation) { relation_class.new([]) }

        let(:policy_class) do
          Struct.new(:target, :viewer) do
            include ResourcePolicy::Policy

            policy do |c|
              c.policy_target :target
              c.attribute(:contracts).allowed(:read)
            end
          end
        end

        it 'has nothing to vouch for, so it is handed back untouched' do
          expect(protected_resource.contracts).to respond_to(:includes)
        end
      end
    end

    describe 'declarations made inside a group' do
      let(:policy_class) do
        nested_class = contract_policy_class

        Struct.new(:target, :viewer) do
          include ResourcePolicy::Policy

          policy do |c|
            c.policy_target :target
            c.group(:allowed?) do |g|
              g.attribute(:current_contract)
               .allowed(:read)
               .nested { |contract| nested_class.new(contract, viewer) }
            end
          end

          private

          def allowed?
            true
          end
        end
      end

      it 'survives the group merge' do
        expect(protected_resource.current_contract).to be_a(ProtectedResource)
      end
    end

    describe 'declarations inherited by a subclass' do
      let(:subclass) { Class.new(policy_class) }
      let(:policy) { subclass.new(target, viewer) }

      it 'survives inheritance' do
        expect(protected_resource.current_contract).to be_a(ProtectedResource)
      end
    end

    describe 'an app which has not opted in' do
      before do
        ResourcePolicy.instance_variable_set(:@config, nil)
      end

      let(:policy_class) do
        Struct.new(:target, :viewer) do
          include ResourcePolicy::Policy

          policy do |c|
            c.policy_target :target
            c.attribute(:current_contract).allowed(:read)
          end
        end
      end

      it 'behaves exactly as before, handing the value back' do
        expect(protected_resource.current_contract).to be(contract)
      end
    end
  end
end
