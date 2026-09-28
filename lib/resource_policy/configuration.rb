# frozen_string_literal: true

# Root namespace
module ResourcePolicy
  # Global configuration.
  #
  # Usage example:
  #
  #   ResourcePolicy.configure do |config|
  #     config.protectable_class = ->(klass) { klass <= ActiveRecord::Base }
  #     config.nested_protection = Rails.env.local? ? :hard : :soft
  #     config.reporter = ->(event) { Rails.logger.warn(event.message) }
  #   end
  #
  class Configuration
    class UnprotectedNestedValueError < ResourcePolicy::Error; end

    MODES = %i[soft hard].freeze

    # Describes a value a policy was asked to hand out but cannot vouch for. It carries the
    # class rather than the value: it is all the message needs, it is all a relation can give
    # without loading a row, and it keeps records out of log events.
    UnprotectedNestedValue = Struct.new(:policy, :attribute, :value_class, keyword_init: true) do
      def message
        "#{policy.class} attribute #{attribute.name.inspect} returned a #{value_class} " \
          'which has no policy of its own, so its read rules never run. Declare it with ' \
          "`c.attribute(#{attribute.name.inspect}).nested { SomePolicy.new(_1) }`, or, if the " \
          "value needs no policy, with `c.attribute(#{attribute.name.inspect}).unprotected(because: '...')`."
      end
    end

    # Nothing is protectable until the host app says what a guarded value looks like, so a
    # gem consumer that has not opted in keeps its current behaviour exactly.
    DEFAULT_PROTECTABLE_CLASS = ->(_klass) { false }
    DEFAULT_REPORTER = ->(event) { warn(event.message) }

    # Answers "does this kind of value have to carry a policy of its own?".
    #
    # Called with the class of every value a protected resource is about to return, never with
    # the value itself. A class is what an unloaded relation can answer for free, so a list
    # attribute is decided without a query; asking about the value would mean loading a row
    # behind every list read. A class which passes needs a `.nested` or `.unprotected`
    # declaration, anything else (strings, numbers, dates, value objects) is handed back
    # untouched. Rails apps usually want `->(klass) { klass <= ActiveRecord::Base }`. Leaving it
    # unset disables nested protection entirely.
    attr_accessor :protectable_class

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
      @protectable_class = DEFAULT_PROTECTABLE_CLASS
      @reporter = DEFAULT_REPORTER
      @nested_protection = :hard
    end

    def nested_protection=(mode)
      mode = mode.to_sym

      MODES.include?(mode) || raise(ArgumentError, "unknown mode #{mode.inspect}, expected one of #{MODES.inspect}")

      @nested_protection = mode
    end

    def hard?
      nested_protection == :hard
    end

    def protectable_class?(klass)
      protectable_class.call(klass)
    end

    # Raises (`:hard`) or reports (`:soft`). Deliberately returns nothing useful: the caller
    # decides what to hand back in soft mode, because a collection and a single value are
    # handed back differently.
    def report_unprotected_nested_value(policy:, attribute:, value_class:)
      event = UnprotectedNestedValue.new(policy: policy, attribute: attribute, value_class: value_class)

      raise UnprotectedNestedValueError, event.message if hard?

      reporter.call(event)
      nil
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
