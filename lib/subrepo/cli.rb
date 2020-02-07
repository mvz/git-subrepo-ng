# frozen_string_literal: true

require "gli"
require "subrepo/commands"
require "subrepo/version"
require "subrepo/runner"

module Subrepo
  # Command line interface for the subrepo commands
  class CLI
    include GLI::App
    include Subrepo::Commands

    def setup
      program_desc "Subrepos -- improved"

      version VERSION

      switch :quiet

      setup_init_command
      setup_clone_command
      setup_fetch_command
      setup_merge_command
      setup_pull_command
      setup_push_command
      setup_status_command
      setup_config_command
      setup_clean_command
    end

    def setup_init_command
      desc "Initialize a subrepo"
      arg :dir
      command :init do |cmd|
        cmd.flag [:remote, :r], arg_name: "url"
        cmd.flag [:branch, :b], arg_name: "branch"
        cmd.flag [:method, :M]
        cmd.action do |_, options, args|
          command_init args.shift, **options.slice(:remote, :branch, :method)
        end
      end
    end

    def setup_clone_command
      desc "Clone a subrepo"
      arg :remote
      arg :dir
      command :clone do |cmd|
        cmd.flag [:branch, :b], arg_name: "branch"
        cmd.flag [:method, :M]
        cmd.switch :force, default_value: false
        cmd.action(&method(:run_clone_command))
      end
    end

    def setup_fetch_command
      desc "Fetch latest commits from a subrepo's remote"
      arg :dir
      command :fetch do |cmd|
        cmd.flag [:remote, :r], arg_name: "url"
        cmd.action do |_, options, args|
          command_fetch(args.shift, remote: options[:remote])
        end
      end
    end

    def setup_pull_command
      desc "Pull upstream changes into a subrepo"
      arg :dir
      command :pull do |cmd|
        cmd.switch :squash, default_value: true
        cmd.flag [:remote, :r], arg_name: "url"
        cmd.flag [:branch, :b], arg_name: "branch"
        cmd.switch [:update, :u], default_value: false
        cmd.action(&method(:run_pull_command))
      end
    end

    def setup_push_command
      desc "Push latest changes to a subrepo to its remote"
      arg :dir
      command :push do |cmd|
        cmd.flag [:remote, :r], arg_name: "url"
        cmd.flag [:branch, :b], arg_name: "branch"
        cmd.switch :force, default_value: false
        cmd.action do |_, options, args|
          command_push(args.shift, remote: options[:remote], branch: options[:branch],
                       force: options[:force])
        end
      end
    end

    def setup_merge_command
      desc "Squash-merge latest fetched commits into a subrepo"
      arg :dir
      command :merge do |cmd|
        cmd.action do |_, _options, args|
          command_merge(args.shift, squash: true)
        end
      end
    end

    def setup_status_command
      desc "Status"
      command :status do |cmd|
        cmd.switch :all, default_value: false
        cmd.switch :all_recursive, default_value: false
        cmd.action do |_, options, _args|
          command_status(recursive: options[:all_recursive])
        end
      end
    end

    def setup_config_command
      desc "Config"
      command :config do |cmd|
        cmd.action do |_, _options, args|
          command_config(args[0], option: args[1], value: args[2])
        end
      end
    end

    def setup_clean_command
      desc "Clean subrepo stuff"
      arg :dir
      command :clean do |cmd|
        cmd.action(&method(:run_clean_command))
      end
    end

    def run_clone_command(global_options, options, args)
      Runner.new(**global_options.slice(:quiet))
        .clone(args[0], args[1], **options.slice(:subdir, :branch, :method, :force))
    end

    def run_pull_command(global_options, options, args)
      Runner.new(**global_options.slice(:quiet))
        .pull(args.shift, **options.slice(:squash, :remote))
    end

    def run_clean_command(global_options, options, args)
      # Nothing yet
    end
  end
end
