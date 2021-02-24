# frozen_string_literal: true

require 'contextual_logger'

class TestEscalateGemWithDefaultLogger
  include Escalate.mixin
end

class TestEscalateGemWithLogger
  include Escalate.mixin

  class << self
    def logger
      @logger ||= Logger.new(STDOUT)
    end
  end
end

class TestEscalateGemWithBlock
  include Escalate.mixin { some_other_logger }

  class << self
    def some_other_logger
      @some_other_logger ||= Logger.new(STDOUT)
    end
  end
end

RSpec.describe Escalate do
  let(:exception) {
    begin
      raise 'oops'
    rescue => ex
      ex
    end
  }

  before do
    allow(Time).to receive(:now).and_return(Time.parse("2021-02-01"))
  end

  it "has a version number" do
    expect(Escalate::VERSION).not_to be nil
  end

  describe "#mixin" do
    subject { described_class.mixin }
    it { should be_a(Module) }

    context "when there is not logger" do
      it 'uses a default logger' do
        expect(TestEscalateGemWithDefaultLogger.send(:default_escalate_logger)).to receive(:error)
        TestEscalateGemWithDefaultLogger.escalate(exception, "I was doing something and got this exception")
      end
    end

    context "when self.logger exists" do
      it 'uses the logger returned by the logger method' do
        expect(TestEscalateGemWithLogger.logger).to receive(:error)
        TestEscalateGemWithLogger.escalate(exception, "I was doing something and got this exception")
      end
    end

    context "when a block is passed to the mixin" do
      it 'uses the logger returned by the block' do
        expect(TestEscalateGemWithBlock.some_other_logger).to receive(:error)
        TestEscalateGemWithBlock.escalate(exception, "I was doing something and got this exception")
      end
    end
  end

  describe "#escalate" do
    context "when context is passed" do
      let(:log_context) { { hello: "world", more: "context" } }
      let(:log_message) { "[Escalate] I was doing something and got this exception (#{log_context.inspect})\n  #{exception.class.name}: #{exception.message}\n  #{exception.backtrace.join("\n")}\n" }

      before { allow(TestEscalateGemWithLogger).to receive(:logger).and_return(logger) }

      context "when the logger extends ContextualLogger" do
        let(:logger) { Logger.new(STDOUT).tap { |log| log.extend ContextualLogger::LoggerMixin } }
        let(:expected_log_line) do
          {
            message: log_message,
            severity: "ERROR",
            timestamp: Time.now,
            hello: "world",
            more: "context"
          }.to_json
        end

        it 'includes the provided context in the json log entry' do
          expect do
            TestEscalateGemWithLogger.escalate(exception, "I was doing something and got this exception", hello: "world", more: "context")
          end.to output("#{expected_log_line}\n").to_stdout_from_any_process
        end
      end
    end
  end

  describe "#on_escalate" do
    let(:callback) do
      -> (_exception, _message, **_context) { }
    end

    describe "log_first: true (default)" do
      before { described_class.on_escalate(&callback) }

      it 'registers the block provided' do
        expect(described_class.send(:on_escalate_blocks)).to include(callback)
      end

      context 'when escalate is called' do
        let(:logger) { instance_double(Logger) }
        before do
          allow(TestEscalateGemWithLogger).to receive(:logger).and_return(logger)
          expect(logger).to receive(:error).with(/\[Escalate\] I was doing something and got this exception .*:hello=>.*world.*, :more=>.*context/)
        end

        it 'executes the callback' do
          expect(callback).to receive(:call).with(exception, "I was doing something and got this exception", hello: "world", more: "context")
          TestEscalateGemWithLogger.escalate(exception, "I was doing something and got this exception", hello: "world", more: "context")
        end
      end
    end

    describe "log_first: true (explicit)" do
      before { described_class.on_escalate(log_first: true, &callback) }

      it 'registers the block provided' do
        expect(described_class.send(:on_escalate_blocks)).to include(callback)
      end
    end
  end
end
