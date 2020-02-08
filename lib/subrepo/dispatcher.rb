# frozen_string_literal: true

require "subrepo/runner"

module Subrepo
  # Dispatch commands from the CLI to the Runner
  class Dispatcher
    def initialize(global_options, options, args)
      @global_options = global_options
      @options = options
      @args = args
    end

    def run_init_command
      runner.run_init(args[0], **options.slice(:remote, :branch, :method))
    end

    def run_branch_command
      if options[:all]
        runner.run_branch_all
      else
        runner.run_branch(args[0])
      end
    end

    def run_clone_command
      runner
        .run_clone(args[0], args[1], **options.slice(:subdir, :branch, :method, :force))
    end

    def run_pull_command
      runner
        .run_pull(args.shift,
                  **options.slice(:squash, :remote, :branch, :message, :edit, :update))
    end

    def run_push_command
      runner.run_push(args.shift,
                      **options.slice(:remote, :branch, :force))
    end

    def run_clean_command
      # Nothing yet
    end

    private

    attr_reader :global_options, :options, :args

    def runner
      @runner ||= Runner.new(**global_options.slice(:quiet))
    end
  end
end
