# frozen_string_literal: true

require "subrepo/config"

module Subrepo
  # Command runner
  class Runner
    attr_reader :quiet

    def initialize(quiet: true)
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

    def clone(remote, subdir=nil, branch: nil, method: nil)
      remote or raise "No remote provided"
      subdir ||= remote.sub(/\.git$/, "").sub(%r{/$}, "").sub(%r{.*/}, "")
      branch ||= "master"
      method ||= "merge"

      repo = Rugged::Repository.new(".")
      raise "You can't clone into an empty repository" if repo.empty?

      last_subdir_commit = `git log -n 1 --pretty=format:%H -- "#{subdir}"`.chomp
      last_subdir_commit.empty? or
        raise "The subdir '#{subdir}' is already part of this repo."

      Commands.perform_fetch(subdir, remote, branch, nil) or
        raise "Unable to fetch from #{remote}"

      refs_subrepo_fetch = "refs/subrepo/#{subdir}/fetch"
      last_fetched_commit = repo.ref(refs_subrepo_fetch).target_id
      system "git read-tree --prefix=\"#{subdir}\" -u \"#{last_fetched_commit}\"" or raise "Command failed"

      config = Config.new(subdir)
      config_name = config.file_name
      config.create(remote, branch, method)
      config.commit = last_fetched_commit
      config.parent = repo.head.target.oid

      index = repo.index
      index.add config_name
      index.write
      Rugged::Commit.create(repo, tree: index.write_tree,
                            message: "Clone remote #{remote} into #{subdir}",
                            parents: [repo.head.target], update_ref: "HEAD")

      puts "Subrepo '#{remote}' (#{branch}) cloned into '#{subdir}'." unless quiet
    end
  end
end
