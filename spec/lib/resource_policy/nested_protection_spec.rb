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

        attr_reader :klass, :loads

        def initialize(items, klass:)
          @items = items
          @klass = klass
          @loads = 0
        end

        def each(&block)
          @loads += 1
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
      ResourcePolicy.config.protectable_class = ->(klass) { klass <= record_class }
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

          it 'hands back the record itself, exactly as the target returned it' do
            expect(protected_resource.current_contract).to be(contract)
          end

          it 'says nothing, because a declaration is visible in the policy already' do
            protected_resource.current_contract

            expect(reported).to be_empty
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

            it 'hands the record over, because soft applies no declaration' do
              expect(protected_resource.current_contract).to be(contract)
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

            it 'hands the collection back untouched, items and all' do
              expect(protected_resource.contracts).to eq([contract])
            end

            it 'says nothing' do
              protected_resource.contracts

              expect(reported).to be_empty
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

    # The rule which matters during a rollout: adding a `.nested` declaration must not change
    # anything until `:hard` is switched on.
    describe 'an attribute the nested policy denies' do
      let(:contract_policy_class) do
        Struct.new(:contract, :viewer) do
          include ResourcePolicy::Policy

          policy do |c|
            c.policy_target :contract
            c.action(:read).allowed
            c.attribute(:hours).allowed(:read, if: :hours_readable?)
          end

          private

          def hours_readable?
            viewer.hours_reader?
          end
        end
      end

      let(:viewer) { double('Viewer', hours_reader?: false) } # rubocop:disable RSpec/VerifiedDoubles

      it 'is nil on :hard' do
        expect(protected_resource.current_contract.hours).to be_nil
      end

      context 'when configured soft' do
        before { ResourcePolicy.config.nested_protection = :soft }

        it 'is the raw record, so the value is reachable exactly as it was' do
          expect(protected_resource.current_contract.hours).to eq(37)
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
      let(:relation) { relation_class.new([contract], klass: contract_class) }
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

      # The decision is taken on every list read on every screen, so it has to cost nothing.
      # `loads` counts the times the relation was enumerated.
      context 'when deciding what to do with it' do
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

        it 'reads no row from an undeclared relation' do
          protected_resource.contracts

          expect(relation.loads).to eq(0)
        end

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

          it 'reads no row' do
            protected_resource.contracts

            expect(relation.loads).to eq(0)
          end
        end

        context 'when the host app has not switched protection on' do
          before { ResourcePolicy.config.protectable_class = Configuration::DEFAULT_PROTECTABLE_CLASS }

          it 'reads no row' do
            protected_resource.contracts

            expect(relation.loads).to eq(0)
          end
        end

        context 'when the attribute declares a nested policy' do
          let(:policy_class) do
            nested_class = contract_policy_class

            Struct.new(:target, :viewer) do
              include ResourcePolicy::Policy

              policy do |c|
                c.policy_target :target
                c.attribute(:contracts)
                 .allowed(:read)
                 .nested { |contract| nested_class.new(contract, viewer) }
              end
            end
          end

          it 'reads no row on :soft, because the declaration is not applied' do
            protected_resource.contracts

            expect(relation.loads).to eq(0)
          end

          it 'reads it once on :hard, because every item has to be wrapped' do
            ResourcePolicy.config.nested_protection = :hard
            protected_resource.contracts

            expect(relation.loads).to eq(1)
          end
        end
      end

      context 'when the collection is empty' do
        let(:relation) { relation_class.new([], klass: contract_class) }

        let(:policy_class) do
          Struct.new(:target, :viewer) do
            include ResourcePolicy::Policy

            policy do |c|
              c.policy_target :target
              c.attribute(:contracts).allowed(:read)
            end
          end
        end

        it 'is still decided, because a relation knows its item class whether or not it holds rows' do
          expect { protected_resource.contracts }
            .to raise_error(Configuration::UnprotectedNestedValueError, /:contracts/)
        end
      end
    end

    describe 'an array-backed collection' do
      let(:target) { target_class.new(contract, items, 'John') }

      let(:policy_class) do
        Struct.new(:target, :viewer) do
          include ResourcePolicy::Policy

          policy do |c|
            c.policy_target :target
            c.attribute(:contracts).allowed(:read)
          end
        end
      end

      context 'when it holds records' do
        let(:items) { [contract] }

        it 'is decided from the item it already holds in memory' do
          expect { protected_resource.contracts }
            .to raise_error(Configuration::UnprotectedNestedValueError, /:contracts/)
        end
      end

      context 'when it is empty' do
        let(:items) { [] }

        it 'says nothing about what it would have held, so it is handed back untouched' do
          expect(protected_resource.contracts).to eq([])
        end
      end
    end

    # The question the rollout turns on: with declarations in place, is `:soft` distinguishable
    # from an application which has never heard of this gem?
    describe 'soft against no protection at all' do
      let(:relation) { relation_class.new([contract, nil], klass: contract_class) }
      let(:target) { target_class.new(contract, relation, 'John') }

      def read_everything
        {
          single: protected_resource.current_contract,
          list: protected_resource.contracts,
          plain: protected_resource.name
        }
      end

      # The baseline is the target itself: what a caller would get with no policy in the way
      # at all, which is what the application does today.
      it 'hands back the very same objects the target would' do
        ResourcePolicy.config.nested_protection = :soft

        expect(read_everything).to eq(
          single: target.current_contract, list: target.contracts, plain: target.name
        )
      end

      it 'leaves the list a relation, not an array' do
        ResourcePolicy.config.nested_protection = :soft

        expect(protected_resource.contracts).to be(relation)
      end

      it 'keeps every item in it, including the empty ones' do
        ResourcePolicy.config.nested_protection = :soft

        expect(protected_resource.contracts.to_a).to eq([contract, nil])
      end

      it 'never reads a row from it' do
        ResourcePolicy.config.nested_protection = :soft
        protected_resource.contracts

        expect(relation.loads).to eq(0)
      end

      it 'is distinguishable on :hard, which is where the declaration takes effect' do
        expect(protected_resource.contracts).to be_a(Array)
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
