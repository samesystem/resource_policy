# frozen_string_literal: true

module ResourcePolicy
  # Global configuration.
  #
  # Usage example:
  #
  #   ResourcePolicy.configure do |config|
  #     config.protectable = ->(value) { value.is_a?(ActiveRecord::Base) }
  #     config.nested_protection = Rails.env.local? ? :hard : :soft
  #     config.reporter = ->(event) { Rails.logger.warn(event.message) }
  #   end
  #
  class Configuration
    class UnprotectedNestedValueError < ResourcePolicy::Error; end

    MODES = %i[soft hard].freeze

    # Describes a value a policy was asked to hand out but cannot vouch for.
    UnprotectedNestedValue = Struct.new(:policy, :attribute, :value, keyword_init: true) do
      def message
        "#{policy.class} attribute #{attribute.name.inspect} returned a #{value.class} " \
          'which has no policy of its own, so its read rules never run. Declare it with ' \
          "`c.attribute(#{attribute.name.inspect}).nested { SomePolicy.new(_1) }`, or, if the " \
          "value needs no policy, with `c.attribute(#{attribute.name.inspect}).unprotected(because: '...')`."
      end
    end

    # Describes a nested value the viewer is not allowed to read.
    DeniedNestedRead = Struct.new(:policy, :attribute, :nested_policy, keyword_init: true) do
      def message
        "#{policy.class} attribute #{attribute.name.inspect} is guarded by #{nested_policy.class}, " \
          'which denies reading it. The value is being handed over anyway because ' \
          '`nested_protection` is :soft. On :hard it is withheld.'
      end
    end

    # Nothing is protectable until the host app says what a guarded value looks like, so a
    # gem consumer that has not opted in keeps its current behaviour exactly.
    DEFAULT_PROTECTABLE = ->(_value) { false }
    DEFAULT_REPORTER = ->(event) { warn(event.message) }

    # Answers "is this value something which must carry a policy of its own?".
    # Called with every value a protected resource is about to return: a value which passes
    # needs a `.nested` or `.unprotected` declaration, anything else (strings, numbers, dates,
    # value objects) is handed back untouched. Rails apps usually want
    # `->(value) { value.is_a?(ActiveRecord::Base) }`. Leaving it unset disables nested
    # protection entirely.
    attr_accessor :protectable

    # Called with an UnprotectedNestedValue whenever the `:soft` mode is in use.
    # Exists so the host app can add its own context (current user, client, request id) to the
    # log line, which this gem has no way of knowing.
    attr_accessor :reporter

    # How hard the gem leans on a nested value it cannot vouch for:
    #
    #   :soft - never changes what a caller gets. An undeclared value is handed over, a value
    #           whose policy denies the read is handed over, and both are reported. This is the
    #           mode an app runs in while the gaps are collected from its logs.
    #   :hard - enforces. An undeclared value raises, because nobody can vouch for it; a value
    #           whose policy denies the read is withheld.
    attr_reader :nested_protection

    def initialize
      @protectable = DEFAULT_PROTECTABLE
      @reporter = DEFAULT_REPORTER
      @nested_protection = :hard
    end

    def nested_protection=(mode)
      mode = mode.to_sym
      unless MODES.include?(mode)
        raise ArgumentError, "unknown mode #{mode.inspect}, expected one of #{MODES.inspect}"
      end

      @nested_protection = mode
    end

    def hard?
      nested_protection == :hard
    end

    def protectable?(value)
      protectable.call(value)
    end

    # Raises (`:hard`) or reports (`:soft`). Deliberately returns nothing useful: the caller
    # decides what to hand back in soft mode, because a collection and a single value are
    # handed back differently.
    def report_unprotected_nested_value(policy:, attribute:, value:)
      event = UnprotectedNestedValue.new(policy: policy, attribute: attribute, value: value)

      raise UnprotectedNestedValueError, event.message if hard?

      reporter.call(event)
      nil
    end

    # Reports a nested value the viewer may not read, and answers whether it has to be
    # withheld. `:soft` reports and hands it over, so turning the mode on cannot change what
    # any caller sees; `:hard` withholds it.
    def withhold_denied_nested_read?(policy:, attribute:, nested_policy:)
      return true if hard?

      reporter.call(
        DeniedNestedRead.new(policy: policy, attribute: attribute, nested_policy: nested_policy)
      )
      false
    end
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield(config)
    config
  end
end
