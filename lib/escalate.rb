# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"

require_relative "escalate/version"

module Escalate
  class Error < StandardError; end

  class << self
    def mixin(&block)
      Module.new do
        def ex_escalate(exception, message)
          escalate_logger.error <<~EOS
            [Escalate] #{message}
              #{exception.class.name}: #{exception.message}
              #{exception.backtrace.join("\n")}
          EOS
        end

        protected

        if block
          define_method(:escalate_logger_from_block, &block)
        else
          define_method(:escalate_logger_from_block, -> {})
        end

        def escalate_logger
          escalate_logger_from_block || self.try(:logger) || default_escalate_logger
        end

        def default_escalate_logger
          @default_escalate_logger ||= Logger.new(STDERR)
        end
      end
    end
  end
end
