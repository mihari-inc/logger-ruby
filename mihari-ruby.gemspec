# frozen_string_literal: true

require_relative "lib/mihari/version"

Gem::Specification.new do |spec|
  spec.name = "mihari-logger"
  spec.version = Mihari::VERSION
  spec.authors = ["Mihari Contributors"]
  spec.email = ["oss@mihari.dev"]

  spec.summary = "Log collection and transport library for the Mihari platform"
  spec.description = "A lightweight, thread-safe Ruby client for collecting and " \
                     "shipping structured logs to the Mihari log ingestion API. " \
                     "Features batching, gzip compression, automatic retries, and " \
                     "a drop-in Ruby Logger replacement."
  spec.homepage = "https://github.com/mihari/mihari-logger"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib}/**/*", "LICENSE", "README.md"]
  end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "webmock", "~> 3.18"
end
