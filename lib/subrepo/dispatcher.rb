# frozen_string_literal: true

require "subrepo/runner"
require "subrepo/null_output"

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

    def run_status_command
      runner.run_status(recursive: options[:all_recursive])
    end

    def run_config_command
      runner.run_config(args[0], option: args[1], value: args[2])
    end

    def run_fetch_command
      runner.run_fetch(args[0], remote: options[:remote])
    end

    def run_commit_command
      runner.run_commit(args.shift, **options.slice(:squash, :message, :edit))
    end

    def run_clone_command
      runner
        .run_clone(args[0], args[1], **options.slice(:subdir, :branch, :method, :force))
    end

    def run_pull_command
      if options[:all]
        runner.run_pull_all(**options.slice(:squash))
      else
        runner
          .run_pull(args[0],
                    **options.slice(:squash, :remote, :branch, :message, :edit, :update))
      end
    end

    def run_push_command
      runner.run_push(args.shift,
                      **options.slice(:remote, :branch, :force, :squash))
    end

    def run_clean_command
      runner.run_clean(args[0], **options.slice(:force))
    end

    private

    attr_reader :global_options, :options, :args

    def runner
      @runner ||=
        begin
          out = if global_options[:quiet]
                  NullOutput.new
                else
                  $stdout
                end
          Runner.new(output: out)
        end
    end
  end
end
