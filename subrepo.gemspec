# frozen_string_literal: true

require_relative "lib/subrepo/version"

Gem::Specification.new do |spec|
  spec.name = "git-subrepo-ng"
  spec.version = Subrepo::VERSION
  spec.authors = ["Matijs van Zuijlen"]
  spec.email = ["matijs@matijs.net"]

  spec.summary = "Clone of git subrepo, with improvements"
  spec.homepage = "https://github.com/mvz/git-subrepo-ng"
  spec.license = "GPL-3.0+"

  spec.required_ruby_version = ">= 2.5.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mvz/git-subrepo-ng"
  spec.metadata["changelog_uri"] = "https://github.com/mvz/git-subrepo-ng/blob/master/Changelog.md"

  spec.files = File.read("Manifest.txt").split
  spec.rdoc_options = ["--main", "README.md"]
  spec.extra_rdoc_files = ["Changelog.md", "README.md"]
  spec.require_paths = ["lib"]

  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }

  spec.add_runtime_dependency "gli", "~> 2.5"
  spec.add_runtime_dependency "rugged", "~> 1.0"

  spec.add_development_dependency "aruba", "~> 1.0.0"
  spec.add_development_dependency "pry", "~> 0.13.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rake-manifest", "~> 0.1.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.6.0"
  spec.add_development_dependency "rubocop-packaging", "~> 0.5.0"
  spec.add_development_dependency "rubocop-performance", "~> 1.9.0"
  spec.add_development_dependency "rubocop-rspec", "~> 2.1.0"
  spec.add_development_dependency "simplecov", "~> 0.20.0"
end
