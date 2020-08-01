# frozen_string_literal: true

require "rake/file_list"
require_relative "lib/subrepo/version"

Gem::Specification.new do |s|
  s.name = "git-subrepo-ng"
  s.version = Subrepo::VERSION
  s.summary = "Clone of git subrepo, with improvements"
  s.authors = ["Matijs van Zuijlen"]
  s.email = ["matijs@matijs.net"]
  s.homepage = "https://github.com/mvz/git-subrepo-ng"

  s.required_ruby_version = ">= 2.5.0"

  s.license = "GPL-3.0+"

  s.metadata["homepage_uri"] = s.homepage
  s.metadata["source_code_uri"] = "https://github.com/mvz/git-subrepo-ng"
  s.metadata["changelog_uri"] = "https://github.com/mvz/git-subrepo-ng/blob/master/Changelog.md"

  s.files = Rake::FileList["{bin,lib}/**/*", "COPYING"]
    .exclude(*File.read(".gitignore").split)
  s.rdoc_options = ["--main", "README.md"]
  s.extra_rdoc_files = ["Changelog.md", "README.md"]

  s.bindir = "bin"
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }

  s.add_runtime_dependency "gli", "~> 2.5"
  s.add_runtime_dependency "rugged", "~> 1.0"

  s.add_development_dependency "aruba", "~> 1.0.0"
  s.add_development_dependency "pry", "~> 0.13.0"
  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "rspec", "~> 3.0"
  s.add_development_dependency "simplecov", "~> 0.18.5"

  s.require_paths = ["lib"]
end
