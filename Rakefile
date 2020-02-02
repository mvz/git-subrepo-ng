# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "cucumber/rake/task"

RSpec::Core::RakeTask.new(:spec)
Cucumber::Rake::Task.new(:cucumber) do |t|
  t.cucumber_opts = "features --format pretty"
end

namespace :compat do
  task :full do
    success = system "prove test"
    exit 1 unless success
  end

  task :regression do
    test_names = %w(status init clone config pull push push-with-merges)
    test_list = test_names.map { |it| "test/#{it}.t" }.join(" ")

    success = system "prove #{test_list}"
    exit 1 unless success
  end
end

task default: [:spec, :cucumber, "compat:regression"]
