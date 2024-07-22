# frozen_string_literal: true

require_relative "lib/poepod/version"

Gem::Specification.new do |spec|
  spec.name = "poepod"
  spec.version = Poepod::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Utilities for uploading code to Poe"
  spec.description = <<~DESCRIPTION
    Utilities for uploading code to Poe
  DESCRIPTION

  spec.homepage = "https://github.com/riboseinc/poepod"
  spec.license = "BSD-2-Clause"

  spec.required_ruby_version = Gem::Requirement.new(">= 3.0.0")

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.test_files = `git ls-files -- spec/*`.split("\n")

  spec.add_runtime_dependency "git", "~> 1.11"
  spec.add_runtime_dependency "mime-types", "~> 3.3"
  spec.add_runtime_dependency "parallel", "~> 1.20"
  spec.add_runtime_dependency "thor", "~> 1.0"
  spec.add_runtime_dependency "tqdm"

  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "rubocop-rails"
end
