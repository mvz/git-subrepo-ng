# frozen_string_literal: true

require "fileutils"
require "rugged"

require "subrepo/config"
require "subrepo/commands"
require "subrepo/main_repository"
require "subrepo/null_output"
require "subrepo/sub_repository"

module Subrepo
  # Command runner
  class Runner
    include Commands

    attr_reader :output

    def initialize(output: NullOutput.new)
      @output = output
    end

    def run_status(recursive: false)
      subrepos = main_repository.subrepos(recursive: recursive)

      puts "#{subrepos.count} subrepos:"
      subrepos.each do |it|
        puts "Git subrepo '#{it}':"
      end
    end

    def run_config(subdir, option:, value:, force: false)
      subdir or raise "Command 'config' requires arg 'subdir'."
      option or raise "Command 'config' requires arg 'option'."

      subrepo = sub_repository(subdir)
      config = subrepo.config
      if value
        if option == "branch" && !force
          raise "This option is autogenerated, use '--force' to override."
        end

        config.send "#{option}=", value
        puts "Subrepo '#{subdir}' option '#{option}' set to '#{value}'."
      else
        value = config.send option
        puts "Subrepo '#{subdir}' option '#{option}' has value '#{value}'."
      end
    end

    def run_fetch(subdir, remote: nil)
      subdir or raise "Command 'fetch' requires arg 'subdir'."

      subrepo = sub_repository(subdir)
      config = subrepo.config
      remote ||= config.remote
      branch = config.branch
      last_merged_commit = config.commit

      last_fetched_commit = subrepo.perform_fetch(remote, branch)
      if last_fetched_commit == last_merged_commit
        puts "No change"
      else
        puts "Fetched '#{subdir}' from '#{remote}' (#{branch})."
      end
    end

    def run_merge(subdir, squash:, message: nil, edit: false)
      subdir or raise "Command 'merge' requires arg 'subdir'."
      current_branch = `git rev-parse --abbrev-ref HEAD`.chomp

      subrepo = sub_repository(subdir)
      config = subrepo.config
      config_name = config.file_name

      branch = config.branch
      last_merged_commit = config.commit
      last_local_commit = repo.head.target.oid
      last_config_commit = `git log -n 1 --pretty=format:%H -- "#{config_name}"`
      last_fetched_commit = subrepo.last_fetched_commit

      if last_fetched_commit == last_merged_commit
        puts "Subrepo '#{subdir}' is up to date."
        return
      end

      # Check validity of last_merged_commit
      walker = Rugged::Walker.new(repo)
      walker.push last_fetched_commit
      found = walker.to_a.any? { |commit| commit.oid == last_merged_commit }
      unless found
        raise "Last merged commit #{last_merged_commit} not found in fetched commits"
      end

      run_command "git rebase" \
        " --onto #{last_config_commit} #{last_merged_commit} #{last_fetched_commit}" \
        " --rebase-merges" \
        " -X subtree=#{subdir}"

      rebased_head = `git rev-parse HEAD`.chomp
      run_command "git checkout -q #{current_branch}"
      run_command "git merge #{rebased_head} --no-ff --no-edit -q"

      if squash
        run_command "git reset --soft #{last_local_commit}"
        run_command "git commit -q -m WIP"
        config.parent = last_config_commit
      else
        config.parent = rebased_head
      end

      config.commit = last_fetched_commit
      run_command "git add \"#{config_name}\""

      message ||=
        "Subrepo-merge #{subdir}/#{branch} into #{current_branch}\n\n" \
        "merged:   \\\"#{last_fetched_commit}\\\""

      command = "git commit -q -m \"#{message}\" --amend"
      if edit
        run_command "#{command} --edit"
      else
        run_command command
      end
    end

    def run_init(subdir, remote: nil, branch: nil, method: nil)
      branch ||= "master"
      remote ||= "none"
      method ||= "merge"
      subdir or raise "Command 'init' requires arg 'subdir'."

      subrepo = sub_repository(subdir)

      File.exist? subdir or raise "The subdir '#{subdir} does not exist."
      config = subrepo.config
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
      if remote == "none"
        puts "Subrepo created from '#{subdir}' (with no remote)."
      else
        puts "Subrepo created from '#{subdir}' with remote '#{remote}' (#{branch})."
      end
    end

    def run_pull(subdir, squash:, remote: nil, branch: nil, message: nil,
                 edit: false, update: false)
      subdir or raise "Command 'pull' requires arg 'subdir'."
      subrepo = sub_repository(subdir)

      config = subrepo.config
      remote ||= config.remote
      branch ||= config.branch
      last_merged_commit = config.commit

      config.branch = branch if update

      last_fetched_commit = subrepo.perform_fetch(remote, branch)
      if last_fetched_commit == last_merged_commit
        puts "Subrepo '#{subdir}' is up to date."
      else
        run_merge(subdir, squash: squash, message: message, edit: edit)
        puts "Subrepo '#{subdir}' pulled from '#{remote}' (master)."
      end
    end

    def run_push(subdir, remote: nil, branch: nil, force: false)
      subdir or raise "Command 'push' requires arg 'subdir'."

      subrepo = sub_repository(subdir)
      config = subrepo.config

      remote ||= config.remote
      branch ||= config.branch
      last_merged_commit = config.commit

      last_fetched_commit = subrepo.perform_fetch(remote, branch)

      if last_fetched_commit && !force
        last_fetched_commit == last_merged_commit or
          raise "There are new changes upstream, you need to pull first."
      end

      last_commit = subrepo.make_local_commits_branch

      unless last_commit
        if last_fetched_commit
          puts "Subrepo '#{subdir}' has no new commits to push."
        else
          warn "Nothing mapped"
        end
        return
      end

      split_branch_name = subrepo.split_branch_name
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

      puts "Subrepo '#{subdir}' pushed to '#{remote}' (#{branch})."
    end

    def run_branch_all
      main_repository.subrepos.each { |subdir| run_branch subdir }
    end

    def run_branch(subdir)
      subdir or raise "Command 'branch' requires arg 'subdir'."

      subrepo = sub_repository(subdir)
      subrepo.make_local_commits_branch

      puts "Created branch '#{subrepo.split_branch_name}'" \
        " and worktree '.git/tmp/subrepo/#{subdir}'."
    end

    def run_clone(remote, subdir = nil, branch: nil, method: nil, force: false)
      remote or raise "Command 'clone' requires arg 'remote'."
      subdir ||= remote.sub(/\.git$/, "").sub(%r{/$}, "").sub(%r{.*/}, "")
      branch ||= "master"
      method ||= "merge"

      raise "You can't clone into an empty repository" if repo.empty?

      unless force
        last_subdir_commit = `git log -n 1 --pretty=format:%H -- "#{subdir}"`.chomp
        last_subdir_commit.empty? or
          raise "The subdir '#{subdir}' is already part of this repo."
      end

      subrepo = sub_repository(subdir)
      subrepo.perform_fetch(remote, branch) or raise "Unable to fetch from #{remote}"
      last_fetched_commit = subrepo.last_fetched_commit

      config = subrepo.config

      if force
        if config.commit == last_fetched_commit
          puts "Subrepo '#{subdir}' is up to date."
          return
        end
        run_command "git rm -r \"#{subdir}\""
      end
      run_command "git read-tree --prefix=\"#{subdir}\" -u \"#{last_fetched_commit}\""

      parent_commit = repo.head.target

      config_name = config.file_name
      config.create(remote, branch, method)
      config.commit = last_fetched_commit
      config.parent = parent_commit.oid

      index = repo.index
      index.add config_name
      index.write
      Rugged::Commit.create(repo, tree: index.write_tree,
                            message: "Clone remote #{remote} into #{subdir}",
                            parents: [parent_commit], update_ref: "HEAD")

      puts "Subrepo '#{remote}' (#{branch}) cloned into '#{subdir}'."
    end

    def run_clean(subdir, force: false)
      subdir or raise "Command 'clean' requires arg 'subdir'."
      subrepo = sub_repository(subdir)
      subrepo.remove_local_commits_branch
      subrepo.remove_fetch_ref if force
      puts "Removed branch '#{subrepo.split_branch_name}'."
    end

    private

    def puts(*args)
      output.puts(*args)
    end

    def main_repository
      @main_repository ||= MainRepository.new
    end

    def sub_repository(subdir)
      SubRepository.new(main_repository, subdir)
    end

    def repo
      @repo ||= main_repository.repo
    end
  end
end
