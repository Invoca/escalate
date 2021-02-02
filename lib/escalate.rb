# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"

require_relative "escalate/version"
require_relative "escalate/mixin"

module Escalate
  class Error < StandardError; end

  class << self
    # Logs and escalated an exception
    #
    # @param [Exception] exception
    #   The exception that was raised and needs to be escalated
    #
    # @param [String] message
    #   An additional message about what was happening at the time of the exception
    #
    # @param [Logger] logger
    #   The logger object to use when logging the exception
    #
    # @param [Hash] context
    #   Any additional context to be tied to the escalation
    def escalate(exception, message, logger, **context)
      ensure_failsafe("Exception rescued while escalating #{exception.inspect}") do
        error_message = <<~EOS
          [Escalate] #{message} (#{context.inspect})
            #{exception.class.name}: #{exception.message}
            #{exception.backtrace.join("\n")}
        EOS

        if logger_allows_added_context?(logger)
          logger.error(error_message, **context)
        else
          logger.error(error_message)
        end

        on_escalate_blocks.each do |block|
          ensure_failsafe("Exception rescued while escalating #{exception.inspect} to #{block.inspect}") do
            block.call(exception, message, **context)
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

        def escalate(exception, message, **context)
          Escalate.escalate(exception, message, escalate_logger, **context)
        end

        private

        def escalate_logger
          escalate_logger_block.try(:call) || default_escalate_logger
        end

        def default_escalate_logger
          @default_escalate_logger ||= Logger.new(STDERR)
        end
      end
    end

    # Registers an escalation callback to be executed when `escalate`
    # is invoked.
    def on_escalate(&block)
      on_escalate_blocks.add(block)
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

    def on_escalate_blocks
      @on_escalate_blocks ||= Set.new
    end
  end
end
