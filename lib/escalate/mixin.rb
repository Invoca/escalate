# frozen_string_literal: true

module Escalate
  module Mixin
    class << self
      def included(base)
        raise 'instead of `include Escalate::Mixin`, you should `include Escalate.mixin`'
      end
    end
  end
end
