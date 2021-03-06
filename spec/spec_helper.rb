# frozen_string_literal: true

require "escalate"

RSpec::Matchers.define :be_exception do |klass, message|
  match do |actual|
    expect(actual).to be_a(klass)
    expect(actual.message).to eq(message)
  end
end

RSpec.configure do |config|
  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
    c.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = 2_000
end
