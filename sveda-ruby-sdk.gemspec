# frozen_string_literal: true

require_relative "lib/sveda/version"

Gem::Specification.new do |spec|
  spec.name = "sveda-ruby-sdk"
  spec.version = Sveda::VERSION
  spec.authors = ["Neresson"]
  spec.summary = "Embed a Sveda AI agent from Ruby or Rails. https://sveda.dev/docs/hosts/ruby"
  spec.description = "Ruby / Rails host SDK for Sveda: embed tokens, streaming chat, and host MCP. Docs: https://sveda.dev/docs/hosts/ruby"
  spec.homepage = "https://sveda.dev/docs/hosts/ruby"
  spec.license = "AGPL-3.0-only"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/neresson/sveda-ruby-sdk"
  spec.metadata["documentation_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/neresson/sveda-ruby-sdk/blob/main/README.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*", "LICENSE", "README.md"].reject { |path| File.directory?(path) }
  end
  spec.require_paths = ["lib"]
  spec.add_dependency "rack", ">= 2.2"
end
