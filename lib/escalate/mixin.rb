# frozen_string_literal: true

module Escalate
  module Mixin
    class << self
      def included(base)
        raise 'instead of `include ExEscalator::Mixin`, you should `include ExEscalator.mixin`'
      end
    end

    attr_accessor :escalate_logger_block

    def ex_escalate(exception, message, **context)
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
