# frozen_string_literal: true

require "subrepo/config"

module Subrepo
  # Command runner
  class Runner
    attr_reader :quiet

    def initialize(quiet: false)
      @quiet = quiet
    end

    def pull(subdir, squash:, remote: nil)
      subdir or raise "No subdir provided"
      config = Config.new(subdir)
      remote ||= config.remote
      branch = config.branch
      last_merged_commit = config.commit

      last_fetched_commit = Commands.perform_fetch(subdir, remote, branch, last_merged_commit)
      if last_fetched_commit == last_merged_commit
        puts "Subrepo '#{subdir}' is up to date." unless quiet
      else
        Commands.command_merge(subdir, squash: squash)
        puts "Subrepo '#{subdir}' pulled from '#{remote}' (master)." unless quiet
      end
    end
  end
end
