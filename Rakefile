# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "cucumber/rake/task"
require "rake/manifest"

RSpec::Core::RakeTask.new(:spec)
Cucumber::Rake::Task.new(:cucumber) do |t|
  t.cucumber_opts = "features --format pretty"
end

REGRESSION_TEST_NAMES = %w(
  branch
  branch-all
  branch-rev-list
  branch-rev-list-one-path
  clean
  clone
  clone-annotated-tag
  config
  encode
  error
  fetch
  gitignore
  init
  issue29
  issue95
  issue96
  pull
  pull-all
  pull-merge
  pull-merge-no-squash
  pull-message
  pull-new-branch
  pull-new-branch-no-squash
  pull-no-squash
  pull-ours
  pull-theirs
  pull-twice
  pull-worktree
  push
  push-after-init
  push-force
  push-new-branch
  push-no-changes
  push-no-squash
  push-squash
  push-with-merges
  push-with-merges-no-squash
  reclone
  status
  submodule
).freeze

namespace :compat do
  task :full do
    success = system "prove test"
    exit 1 unless success
  end

  desc "Run integration tests from git-subrepo"
  task :regression do
    test_list = REGRESSION_TEST_NAMES.map { |it| "test/#{it}.t" }.join(" ")

    success = system "prove #{test_list}"
    exit 1 unless success
  end
end

Rake::Manifest::Task.new do |t|
  t.patterns = ["lib/**/*", "COPYING", "*.md", "bin/*"]
end
task build: "manifest:check"

task default: [:spec, :cucumber, "compat:regression"]
