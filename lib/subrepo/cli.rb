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

      setup_merge_command
    end

    def setup_init_command
      desc "Initialize a subrepo"
      arg :dir
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
      arg :dir
      command :clone do |cmd|
        cmd.flag [:branch, :b], arg_name: "branch"
        cmd.flag [:method, :M]
        cmd.switch :force, default_value: false
        setup_action(cmd, :run_clone_command)
      end
    end

    def setup_branch_command
      desc "Create a branch containing the local subrepo commits"
      arg :dir
      command :branch do |cmd|
        cmd.switch :all, default_value: false
        cmd.switch :fetch, default_value: false
        setup_action(cmd, :run_branch_command)
      end
    end

    def setup_fetch_command
      desc "Fetch latest commits from a subrepo's remote"
      arg :dir
      command :fetch do |cmd|
        cmd.flag [:remote, :r], arg_name: "url"
        setup_action(cmd, :run_fetch_command)
      end
    end

    def setup_pull_command
      desc "Pull upstream changes into a subrepo"
      arg :dir
      command :pull do |cmd|
        cmd.switch :squash, default_value: true
        cmd.flag [:branch, :b], arg_name: "branch"
        cmd.flag [:message, :m], arg_name: "message"
        cmd.flag [:remote, :r], arg_name: "url"
        cmd.switch [:edit, :e], default_value: false
        cmd.switch [:update, :u], default_value: false
        setup_action(cmd, :run_pull_command)
      end
    end

    def setup_push_command
      desc "Push latest changes to a subrepo to its remote"
      arg :dir
      command :push do |cmd|
        cmd.flag [:remote, :r], arg_name: "url"
        cmd.flag [:branch, :b], arg_name: "branch"
        cmd.switch :force, default_value: false
        setup_action(cmd, :run_push_command)
      end
    end

    def setup_merge_command
      desc "Squash-merge latest fetched commits into a subrepo"
      arg :dir
      command :merge do |cmd|
        setup_action(cmd, :run_merge_command)
      end
    end

    def setup_status_command
      desc "Status"
      command :status do |cmd|
        cmd.switch :all, default_value: false
        cmd.switch :all_recursive, default_value: false
        setup_action(cmd, :run_status_command)
      end
    end

    def setup_config_command
      desc "Config"
      command :config do |cmd|
        setup_action(cmd, :run_config_command)
      end
    end

    def setup_clean_command
      desc "Clean subrepo stuff"
      arg :dir
      command :clean do |cmd|
        setup_action(cmd, :run_clean_command)
      end
    end

    def setup_action(cmd, runner_method)
      cmd.action do |global_options, options, args|
        Dispatcher.new(global_options, options, args).send runner_method
      end
    end
  end
end
