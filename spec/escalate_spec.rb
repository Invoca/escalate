# frozen_string_literal: true

class TestEscalateGemWithDefaultLogger
  extend Escalate.mixin
end

class TestEscalateGemWithLogger
  extend Escalate.mixin

  class << self
    def logger
      @logger ||= Logger.new(STDOUT)
    end
  end
end

class TestEscalateGemWithBlock
  extend Escalate.mixin { some_other_logger }

  class << self
    def some_other_logger
      @some_other_logger ||= Logger.new(STDOUT)
    end
  end
end

RSpec.describe Escalate do
  it "has a version number" do
    expect(Escalate::VERSION).not_to be nil
  end

  describe "#mixin" do
    let(:exception) {
      begin
        raise 'oops'
      rescue => ex
        ex
      end
    }

    subject { described_class.mixin }
    it { should be_a(Module) }

    context "when there is not logger" do
      it 'uses a default logger' do
        expect(TestEscalateGemWithDefaultLogger.send(:default_escalate_logger)).to receive(:error)
        TestEscalateGemWithDefaultLogger.ex_escalate(exception, "I was doing something and got this exception")
      end
    end

    context "when self.logger exists" do
      it 'uses the logger returned by the logger method' do
        expect(TestEscalateGemWithLogger.logger).to receive(:error)
        TestEscalateGemWithLogger.ex_escalate(exception, "I was doing something and got this exception")
      end
    end

    context "when a block is passed to the mixin" do
      it 'uses the logger returned by the block' do
        expect(TestEscalateGemWithBlock.some_other_logger).to receive(:error)
        TestEscalateGemWithBlock.ex_escalate(exception, "I was doing something and got this exception")
      end
    end
  end
end
