# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"

require_relative "escalate/version"
require_relative "escalate/mixin"

module Escalate
  class Error < StandardError; end

  LOG_FIRST_INSTANCE_VARIABLE = :@_escalate_log_first

  DEFAULT_RESCUE_EXCEPTIONS       = [StandardError].freeze
  DEFAULT_PASS_THROUGH_EXCEPTIONS = [SystemExit, SystemStackError, NoMemoryError, SecurityError, SignalException].freeze

  @on_escalate_callbacks = {}

  class << self
    attr_reader :on_escalate_callbacks

    # Logs and escalated an exception
    #
    # @param [Exception] exception
    #   The exception that was rescued and needs to be escalated
    #
    # @param [String] location_message
    #   An additional message giving an indication of where in the code this exception was rescued
    #
    # @param [Logger] logger
    #   The logger object to use when logging the exception
    #
    # @param [Hash] context
    #   Any additional context to be tied to the escalation
    def escalate(exception, location_message, logger, context: {})
      ensure_failsafe("Exception rescued while escalating #{exception.inspect}") do
        if on_escalate_callbacks.none? || on_escalate_callbacks.values.any? { |block| block.instance_variable_get(LOG_FIRST_INSTANCE_VARIABLE) }
          logger_allows_added_context?(logger) or context_string = " (#{context.inspect})"
          error_message = <<~EOS
            [Escalate] #{location_message}#{context_string}
            #{exception.class.name}: #{exception.message}
            #{exception.backtrace.join("\n")}
          EOS

          if context_string
            logger.error(error_message)
          else
            logger.error(error_message, **context)
          end
        end

        on_escalate_callbacks.values.each do |block|
          ensure_failsafe("Exception rescued while escalating #{exception.inspect} to #{block.inspect}") do
            block.call(exception, location_message, **context)
          end
        end
      end
    end

    # Returns a module to be mixed into a class or module exposing
    # the escalate method to be used for escalating and logging
    # exceptions.
    #
    # @param [Proc] logger_block
    #   A block to be used to get the logger object that Escalate
    #   should be using
    def mixin(&logger_block)
      Thread.current[:escalate_logger_block] = logger_block

      Module.new do
        def self.included(base)
          base.extend self
          base.escalate_logger_block = Thread.current[:escalate_logger_block] || -> { base.try(:logger) }
        end

        attr_accessor :escalate_logger_block

        def escalate(exception, location_message, context: {})
          Escalate.escalate(exception, location_message, escalate_logger, context: context)
        end

        def rescue_and_escalate(location_message, context: {},
                                exceptions: DEFAULT_RESCUE_EXCEPTIONS,
                                pass_through_exceptions: DEFAULT_PASS_THROUGH_EXCEPTIONS,
                                &block)

          yield

        rescue *Array(pass_through_exceptions)
          raise
        rescue *Array(exceptions) => exception
          escalate(exception, location_message, context: context)
        end

        private

        def escalate_logger
          escalate_logger_block&.call || default_escalate_logger
        end

        def default_escalate_logger
          @default_escalate_logger ||= Logger.new(STDERR)
        end
      end
    end

    # Registers an escalation callback to be executed when `escalate` is invoked.
    #
    # @param [boolean] log_first: true
    #   whether escalate should log first before escalating, or leave the logging to the escalate block
    # @param [string | Array] name:
    #   unique name for this callback block
    #   any previously-registered block with the same name will be discarded
    #   if not provided, name defaults to `block.source_location`
    def on_escalate(log_first: true, name: nil, &block)
      block.instance_variable_set(LOG_FIRST_INSTANCE_VARIABLE, log_first)
      on_escalate_callbacks[name || block.source_location] = block
    end

    def clear_on_escalate_callbacks
      on_escalate_callbacks.clear
    end

    private

    def ensure_failsafe(message)
      yield
    rescue Exception => ex
      STDERR.puts("[Escalator] #{message}: #{ex.class.name}: #{ex.message}")
    end

    def logger_allows_added_context?(logger)
      defined?(ContextualLogger::LoggerMixin) &&
        logger.is_a?(ContextualLogger::LoggerMixin)
    end
  end
end
