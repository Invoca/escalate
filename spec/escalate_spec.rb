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

class DerivedFromException < Exception; end
class SiblingDerivedFromException < Exception; end

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
    Escalate.clear_on_escalate_callbacks
  end

  after do
    Escalate.clear_on_escalate_callbacks
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
      let(:log_message) { "[Escalate] I was doing something and got this exception\n#{exception.class.name}: #{exception.message}\n#{exception.backtrace.join("\n")}\n" }

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
            TestEscalateGemWithLogger.escalate(exception, "I was doing something and got this exception", context: { hello: "world", more: "context" })
          end.to output("#{expected_log_line}\n").to_stdout_from_any_process
        end
      end

      context "when the logger doesn't extend ContextualLogger" do
        let(:logger) { Logger.new(STDOUT) }
        if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.4")
          let(:log_message) { "[Escalate] I was doing something and got this exception ({:hello=>\"world\", :more=>\"context\"})" }
        else
          let(:log_message) { "[Escalate] I was doing something and got this exception ({hello: \"world\", more: \"context\"})" }
        end
        let(:expected_log_line) { /#{Regexp.escape(log_message)}/ }

        it 'includes the provided context at the end of the message' do
          expect do
            TestEscalateGemWithLogger.escalate(exception, "I was doing something and got this exception", context: { hello: "world", more: "context" })
          end.to output(expected_log_line).to_stdout_from_any_process
        end
      end
    end
  end

  describe '#rescue_and_escalate' do
    let(:logger) { Logger.new(STDOUT) }
    let(:location_message) { "I was doing something and got this exception" }
    let(:context) { { hello: "world" } }
    let(:log_message) { "[Escalate] #{location_message} (#{context.inspect})" }
    let(:expected_log_line) { /#{Regexp.escape(log_message)}/ }

    it 'rescues and calls escalate' do
      expect(TestEscalateGemWithLogger).to receive(:escalate).with(be_exception(ArgumentError, 'bang!'), location_message, context: context)

      TestEscalateGemWithLogger.rescue_and_escalate(location_message, context: context) do
        raise ArgumentError, 'bang!'
      end
    end

    context 'with basic defaults' do
      let(:exception_class) { DerivedFromException }
      let(:exception_message) { 'boom!' }
      let(:exceptions) { [DerivedFromException] }
      let(:args) { [location_message] }
      let(:kwargs) { { context: context, exceptions: exceptions } }
      let(:subject) do
        TestEscalateGemWithLogger.rescue_and_escalate(*args, **kwargs) do
          raise exception_class, exception_message
        end
      end

      it 'rescues matching exceptions' do
        expect { subject }.to_not raise_exception
      end

      context 'when non-matching exception raised' do
        let(:exception_class) { SiblingDerivedFromException }

        it 'passes through' do
          expect { subject }.to raise_exception(exception_class, exception_message)
        end
      end

      context 'when broad exceptions rescued' do
        let(:exceptions) { [Exception] }

        context 'but pass-through exception raised' do
          let(:exception_class) { NoMemoryError }

          it 'passes through exception' do
            expect { subject }.to raise_exception(exception_class, exception_message)
          end
        end

        context 'and non-pass-through exception raised' do
          let(:exception_class) { RuntimeError }

          it 'rescues matching exceptions' do
            expect { subject }.to_not raise_exception
          end
        end
      end

      context 'when exceptions: is empty but pass-through exception raised' do
        let(:exceptions) { [] }
        let(:exception_class) { NoMemoryError }

        it 'passes through matching exceptions on the default pass_through_exceptions: list' do
          expect { subject }.to raise_exception(exception_class, exception_message)
        end
      end

      context 'when exceptions: is empty but pass-through exception raised' do
        let(:exceptions) { [] }
        let(:exception_class) { NoMemoryError }

        it 'passes through matching exceptions not on the default pass_through_exceptions: list' do
          expect { subject }.to raise_exception(exception_class, exception_message)
        end
      end

      context 'when pass_through_exceptions: is empty' do
        let(:kwargs) { { context: context, exceptions: exceptions, pass_through_exceptions: [] } }

        context 'and exception raised matching exceptions:' do
          it 'rescues matching exceptions' do
            expect { subject }.to_not raise_exception
          end
        end

        context 'and exception raised not matching exceptions:' do
          let(:exception_class) { SiblingDerivedFromException }

          it 'passes through non-matching exceptions' do
            expect { subject }.to raise_exception(exception_class, exception_message)
          end
        end
      end

      context 'when both exceptions: and pass_through_exceptions: given' do
        let(:exceptions) { [Exception] }
        let(:kwargs) { { context: context, exceptions: exceptions, pass_through_exceptions: [DerivedFromException] } }

        context 'when exception raised that matches exceptions:' do
          let(:exception_class) { SiblingDerivedFromException }

          it 'rescues matching exceptions' do
            expect { subject }.to_not raise_exception
          end
        end

        context 'when exception raised that matches pass_through_exceptions:' do
          let(:exception_class) { DerivedFromException }

          it 'passes through exception' do
            expect { subject }.to raise_exception(exception_class, exception_message)
          end
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
        expect(described_class.on_escalate_callbacks.values).to include(callback)
      end

      context 'when escalate is called' do
        let(:logger) { instance_double(Logger) }
        before do
          allow(TestEscalateGemWithLogger).to receive(:logger).and_return(logger)
          if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.4")
            expect(logger).to receive(:error).with(/\[Escalate\] I was doing something and got this exception .*:hello=>.*world.*, :more=>.*context/)
          else
            expect(logger).to receive(:error).with(/\[Escalate\] I was doing something and got this exception .*{hello:.*world.*, more:.*context/)
          end
        end

        it 'executes the callback' do
          expect(callback).to receive(:call).with(exception, "I was doing something and got this exception", hello: "world", more: "context")
          TestEscalateGemWithLogger.escalate(exception, "I was doing something and got this exception", context: { hello: "world", more: "context" })
        end
      end
    end

    describe "log_first: true (explicit)" do
      before { described_class.on_escalate(log_first: true, &callback) }

      it 'registers the block provided' do
        expect(described_class.on_escalate_callbacks.values).to include(callback)
      end
    end

    describe "log_first: false" do
      before { described_class.on_escalate(log_first: false, &callback) }

      it 'registers the block provided' do
        expect(described_class.on_escalate_callbacks.values).to include(callback)
      end

      context 'when escalate is called' do
        let(:logger) { instance_double(Logger) }
        before do
          allow(TestEscalateGemWithLogger).to receive(:logger).and_return(logger)
          expect(logger).to_not receive(:error)
        end

        it 'executes the callback' do
          expect(callback).to receive(:call).with(exception, "I was doing something and got this exception", hello: "world", more: "context")
          TestEscalateGemWithLogger.escalate(exception, "I was doing something and got this exception", context: { hello: "world", more: "context" })
        end
      end
    end

    describe 'name:' do
      it 'uniques on name:' do
        expect(described_class.on_escalate_callbacks.size).to eq(0)
        described_class.on_escalate(name: 'abc', &callback)
        expect(described_class.on_escalate_callbacks.size).to eq(1)
        described_class.on_escalate(name: 'abc') { }
        expect(described_class.on_escalate_callbacks.size).to eq(1)
      end

      it 'defaults name: to .source_location' do
        expect(described_class.on_escalate_callbacks.size).to eq(0)
        expect(callback).to receive(:source_location) { ['a.rb', 3] }.twice
        described_class.on_escalate(&callback)
        expect(described_class.on_escalate_callbacks.size).to eq(1)
        described_class.on_escalate(&callback)
        expect(described_class.on_escalate_callbacks.size).to eq(1)
      end
    end
  end
end
