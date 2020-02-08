# frozen_string_literal: true

require "fileutils"
require "subrepo/config"
require "subrepo/sub_repository"

module Subrepo
  # Command runner
  class Runner
    attr_reader :quiet

    def initialize(quiet: true)
      @quiet = quiet
    end

    def run_init(subdir, remote: nil, branch: nil, method: nil)
      branch ||= "master"
      remote ||= "none"
      method ||= "merge"
      subdir or raise "Command 'init' requires arg 'subdir'."

      repo = Rugged::Repository.new(".")

      File.exist? subdir or raise "The subdir '#{subdir} does not exist."
      config = Config.new(subdir)
      config_name = config.file_name
      File.exist? config_name and
        raise "The subdir '#{subdir}' is already a subrepo."
      last_subdir_commit = `git log -n 1 --pretty=format:%H -- "#{subdir}"`.chomp
      last_subdir_commit.empty? and
        raise "The subdir '#{subdir}' is not part of this repo."

      config.create(remote, branch, method)

      index = repo.index
      index.add config_name
      index.write
      Rugged::Commit.create(repo, tree: index.write_tree,
                            message: "Initialize subrepo #{subdir}",
                            parents: [repo.head.target], update_ref: "HEAD")
      return if quiet

      if remote == "none"
        puts "Subrepo created from '#{subdir}' (with no remote)."
      else
        puts "Subrepo created from '#{subdir}' with remote '#{remote}' (#{branch})."
      end
    end

    def run_pull(subdir, squash:, remote: nil, branch: nil, message: nil,
                 edit: false, update: false)
      subdir or raise "Command 'pull' requires arg 'subdir'."
      config = Config.new(subdir)
      remote ||= config.remote
      branch ||= config.branch
      last_merged_commit = config.commit

      config.branch = branch if update

      last_fetched_commit = Commands.perform_fetch(subdir, remote, branch,
                                                   last_merged_commit)
      if last_fetched_commit == last_merged_commit
        puts "Subrepo '#{subdir}' is up to date." unless quiet
      else
        Commands.command_merge(subdir, squash: squash, message: message, edit: edit)
        puts "Subrepo '#{subdir}' pulled from '#{remote}' (master)." unless quiet
      end
    end

    def run_push(subdir, remote: nil, branch: nil, force: false)
      subdir or raise "Command 'push' requires arg 'subdir'."

      repo = Rugged::Repository.new(".")

      config = Config.new(subdir)

      remote ||= config.remote
      branch ||= config.branch
      last_merged_commit = config.commit
      last_pushed_commit = config.parent

      fetched = Commands.perform_fetch(subdir, remote, branch, last_merged_commit)

      if fetched && !force
        refs_subrepo_fetch = "refs/subrepo/#{subdir}/fetch"
        last_fetched_commit = repo.ref(refs_subrepo_fetch).target_id
        last_fetched_commit == last_merged_commit or
          raise "There are new changes upstream, you need to pull first."
      end

      split_branch_name = make_split_branch_name(subdir)
      last_commit = make_local_commits_branch(subdir, split_branch_name,
                                              last_pushed_commit: last_pushed_commit,
                                              last_merged_commit: last_merged_commit)

      unless last_commit
        if fetched
          puts "Subrepo '#{subdir}' has no new commits to push." unless quiet
        else
          warn "Nothing mapped"
        end
        return
      end

      if force
        run_command "git push -q --force \"#{remote}\" #{split_branch_name}:#{branch}"
      else
        run_command "git push -q \"#{remote}\" #{split_branch_name}:#{branch}"
      end
      pushed_commit = last_commit

      parent_commit = `git rev-parse HEAD`.chomp

      config.remote = remote
      config.commit = pushed_commit
      config.parent = parent_commit
      run_command "git add -f -- #{config.file_name}"
      run_command "git commit -q -m \"Push subrepo #{subdir}\""

      puts "Subrepo '#{subdir}' pushed to '#{remote}' (#{branch})." unless quiet
    end

    def run_branch(subdir, all: false)
      if all
        main_repository.subrepos.each { |subrepo| run_branch subrepo }
        return
      end

      subdir or raise "Command 'branch' requires arg 'subdir'."

      config = Config.new(subdir)
      last_merged_commit = config.commit
      last_pushed_commit = config.parent

      split_branch_name = make_split_branch_name(subdir)
      make_local_commits_branch(subdir, split_branch_name,
                                last_pushed_commit: last_pushed_commit,
                                last_merged_commit: last_merged_commit)

      return if quiet

      puts "Created branch '#{split_branch_name}'" \
        " and worktree '.git/tmp/subrepo/#{subdir}'."
    end

    def run_clone(remote, subdir = nil, branch: nil, method: nil, force: false)
      remote or raise "Command 'clone' requires arg 'remote'."
      subdir ||= remote.sub(/\.git$/, "").sub(%r{/$}, "").sub(%r{.*/}, "")
      branch ||= "master"
      method ||= "merge"

      repo = Rugged::Repository.new(".")
      raise "You can't clone into an empty repository" if repo.empty?

      unless force
        last_subdir_commit = `git log -n 1 --pretty=format:%H -- "#{subdir}"`.chomp
        last_subdir_commit.empty? or
          raise "The subdir '#{subdir}' is already part of this repo."
      end

      Commands.perform_fetch(subdir, remote, branch, nil) or
        raise "Unable to fetch from #{remote}"

      refs_subrepo_fetch = "refs/subrepo/#{subdir}/fetch"
      last_fetched_commit = repo.ref(refs_subrepo_fetch).target_id

      config = Config.new(subdir)

      if force
        if config.commit == last_fetched_commit
          puts "Subrepo '#{subdir}' is up to date." unless quiet
          return
        end
        run_command "git rm -r \"#{subdir}\""
      end
      run_command "git read-tree --prefix=\"#{subdir}\" -u \"#{last_fetched_commit}\""

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

    private

    def make_local_commits_branch(subdir, split_branch_name,
                                  last_pushed_commit:, last_merged_commit:)
      last_merged_commit = nil if last_merged_commit == ""

      unless repo.branches.exist? split_branch_name
        branch_commit = last_merged_commit || repo.head.target_id
        repo.branches.create split_branch_name, branch_commit
      end

      worktree_name = ".git/tmp/subrepo/#{subdir}"
      worktrees = `git worktree list`

      unless worktrees.include? worktree_name
        run_command "git worktree add \"#{worktree_name}\" \"#{split_branch_name}\""
      end

      Dir.chdir worktree_name do
        subrepo = SubRepository.new(main_repository, subdir)
        mapped_commit = subrepo.map_commits(last_pushed_commit, last_merged_commit)
        return unless mapped_commit

        run_command "git checkout #{split_branch_name}"
        run_command "git reset --hard #{mapped_commit}"
        mapped_commit
      end
    end

    def make_split_branch_name(subdir)
      "subrepo/#{subdir}"
    end

    def main_repository
      @main_repository ||= MainRepository.new
    end

    def repo
      @repo ||= main_repository.repo
    end

    def run_command(command)
      Commands.run_command(command)
    end
  end
end
