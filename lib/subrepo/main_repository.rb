# frozen_string_literal: true

require "rugged"

module Subrepo
  # Main repository, possibly containing subrepo's
  class MainRepository
    include Commands

    attr_reader :repo

    def initialize
      @repo = Rugged::Repository.discover(".")
    end

    def subrepos(recursive: false)
      tree = repo.head.target.tree
      subrepos = []
      tree.walk_blobs do |path, blob|
        next if blob[:name] != ".gitrepo"

        unless recursive
          next if subrepos.any? { |it| path.start_with? it }
        end
        subrepos << path
      end
      subrepos.map(&:chop)
    end

    def check_ready
      repo.head_detached? and raise "Must be on a branch to run this command."
      run_command("git rev-parse --is-inside-work-tree").chomp == "true" or
        raise "Can't run subrepo command outside a working tree."
      File.expand_path(repo.workdir) == Dir.pwd or
        raise "Need to run subrepo command from top level directory of the repo."
    end

    def check_clean
      run_command("git status --porcelain") == "" or
        raise "Ensure your working tree is clean before running subrepo command."
    end
  end
end
