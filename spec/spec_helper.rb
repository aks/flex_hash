# frozen_string_literal: true

# start simplecov if CODE_COVERAGE is truthy
require 'simplecov'
SimpleCov.start if %w[1 on yes true].include?(ENV.fetch('CODE_COVERAGE', 'no'))

require "bundler/setup"
require 'rspec'
require "flex_hash"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
