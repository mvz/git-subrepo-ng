# frozen_string_literal: true

require "gli"
require "subrepo/commands"
require "subrepo/version"
require "subrepo/runner"
require "subrepo/dispatcher"

module Subrepo
  # Command line interface for the subrepo commands
  class CLI
    include GLI::App
    include Subrepo::Commands

    def initialize(output: $stdout)
      super()
      @output = output
    end

    def setup
      program_desc "Subrepos -- improved"

      version VERSION

      switch :quiet

      sort_help :manually

      setup_clone_command
      setup_init_command
      setup_pull_command
      setup_push_command

      setup_branch_command
      setup_fetch_command

      setup_status_command
      setup_clean_command
      setup_config_command

      setup_commit_command

      on_error do |ex|
        output_error_message(ex)
      end
    end

    def setup_init_command
      desc "Initialize a subrepo"
      arg :subdir
      command :init do |cmd|
        cmd.flag [:remote, :r], arg_name: "url"
        cmd.flag [:branch, :b], arg_name: "branch"
        cmd.flag [:method, :M]
        setup_action(cmd, :run_init_command)
      end
    end

    def setup_clone_command
      desc "Clone a subrepo"
      arg :remote
      arg :subdir, :optional
      command :clone do |cmd|
        cmd.flag [:branch, :b], arg_name: "branch"
        cmd.flag [:method, :M]
        cmd.switch :force, default_value: false
        setup_action(cmd, :run_clone_command)
      end
    end

    def setup_branch_command
      desc "Create a branch containing the local subrepo commits"
      arg :subdir, :optional
      command :branch do |cmd|
        cmd.switch :all, default_value: false
        cmd.switch :fetch, default_value: false
        cmd.switch :force, default_value: false
        setup_action(cmd, :run_branch_command)
      end
    end

    def setup_fetch_command
      desc "Fetch latest commits from a subrepo's remote"
      arg :subdir
      command :fetch do |cmd|
        cmd.flag [:remote, :r], arg_name: "url"
        setup_action(cmd, :run_fetch_command)
      end
    end

    def setup_pull_command
      desc "Pull upstream changes into a subrepo"
      arg :subdir, :optional
      command :pull do |cmd|
        cmd.switch :squash, default_value: false
        cmd.flag [:branch, :b], arg_name: "branch"
        cmd.flag [:message, :m], arg_name: "message"
        cmd.flag [:remote, :r], arg_name: "url"
        cmd.switch :all, default_value: false
        cmd.switch [:edit, :e], default_value: false
        cmd.switch [:update, :u], default_value: false
        setup_action(cmd, :run_pull_command)
      end
    end

    def setup_push_command
      desc "Push latest changes to a subrepo to its remote"
      arg :subdir
      command :push do |cmd|
        cmd.flag [:remote, :r], arg_name: "url"
        cmd.flag [:branch, :b], arg_name: "branch"
        cmd.switch :force, default_value: false
        cmd.switch :squash, default_value: false
        # FIXME: Make update actually do something
        cmd.switch [:update, :u], default_value: false
        setup_action(cmd, :run_push_command)
      end
    end

    def setup_commit_command
      desc "commit"
      arg :subdir
      command :commit do |cmd|
        cmd.flag [:message, :m], arg_name: "message"
        cmd.switch :squash, default_value: false
        cmd.switch [:edit, :e], default_value: false
        setup_action(cmd, :run_commit_command)
      end
    end

    def setup_status_command
      desc "Status"
      arg :subdir, :optional
      command :status do |cmd|
        cmd.switch :all, default_value: false
        cmd.switch :all_recursive, default_value: false
        setup_action(cmd, :run_status_command)
      end
    end

    def setup_config_command
      desc "Config"
      arg :subdir
      arg :option
      arg :value, :optional
      command :config do |cmd|
        cmd.switch :force, default_value: false
        setup_action(cmd, :run_config_command)
      end
    end

    def setup_clean_command
      desc "Clean subrepo stuff"
      arg :subdir
      command :clean do |cmd|
        cmd.switch :force, default_value: false
        setup_action(cmd, :run_clean_command)
      end
    end

    def setup_action(cmd, runner_method)
      cmd.action do |global_options, options, args|
        params = []
        cmd.arguments.each do |arg|
          if args.empty?
            next if arg.optional?

            raise "Command '#{cmd.name}' requires arg '#{arg.name}'."
          end

          if arg.multiple?
            params += args
            args.clear
          else
            params << args.shift
          end
        end
        args.empty? or
          raise "Unknown argument(s) '#{args.join(' ')}' for '#{cmd.name}' command."
        Dispatcher.new(global_options, options, params,
                       output: @output).send runner_method
      end
    end
  end
end
