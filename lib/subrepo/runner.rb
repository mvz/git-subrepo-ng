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
      main_repository.check_ready
    end

    def run_status_all(recursive: false)
      subrepos = main_repository.subrepos(recursive: recursive)

      case (count = subrepos.count)
      when 0
        puts "No subrepos"
      when 1
        puts "1 subrepo:"
      else
        puts "#{count} subrepos:"
      end

      subrepos.each do |subdir|
        puts
        run_status subdir
      end
    end

    def run_status(subdir)
      subrepo = sub_repository(subdir)
      config = subrepo.config
      puts "Git subrepo '#{subdir}':"
      puts "  Remote URL:      #{config.remote}"
      puts "  Tracking Branch: #{config.branch}"
      puts "  Pulled Commit:   #{config.commit[0..6]}"
      puts "  Pull Parent:     #{config.parent[0..6]}"
    end

    def run_config(subdir, option:, value:, force: false)
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

    def run_commit(subdir, squash:, message:, edit:)
      main_repository.check_clean

      subrepo = sub_repository(subdir)

      branch = subrepo.config.branch
      current_branch = `git rev-parse --abbrev-ref HEAD`.chomp
      message ||=
        "Subrepo-merge #{subdir}/#{branch} into #{current_branch}\n\n" \
        "merged:   \"#{subrepo.last_fetched_commit}\""

      subrepo.commit_subrepo_commits_into_main_repo(squash: squash,
                                                    message: message,
                                                    edit: edit)
      subrepo.remove_local_commits_branch
    end

    def run_init(subdir, remote: nil, branch: nil, method: nil)
      main_repository.check_clean

      branch ||= "master"
      remote ||= "none"
      method ||= "merge"

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

    def run_pull_all(squash:)
      main_repository.subrepos.each { |subdir| run_pull(subdir, squash: squash) }
    end

    def run_pull(subdir, squash:, remote: nil, branch: nil, message: nil,
                 edit: false, update: false)
      main_repository.check_clean

      subrepo = sub_repository(subdir)

      config = subrepo.config
      remote ||= config.remote
      branch ||= config.branch
      last_merged_commit = config.commit

      config.branch = branch if update

      last_fetched_commit = subrepo.perform_fetch(remote, branch)

      current_branch = `git rev-parse --abbrev-ref HEAD`.chomp
      message ||=
        "Subrepo-merge #{subdir}/#{branch} into #{current_branch}\n\n" \
        "merged:   \"#{last_fetched_commit}\""

      if last_fetched_commit != last_merged_commit
        subrepo.merge_subrepo_commits_into_main_repo(squash: squash,
                                                     message: message,
                                                     edit: edit)
        subrepo.remove_local_commits_branch
      elsif update
        subrepo.commit_config_update(message: message, edit: edit)
      else
        puts "Subrepo '#{subdir}' is up to date."
        return
      end
      puts "Subrepo '#{subdir}' pulled from '#{remote}' (#{branch})."
    end

    def run_push(subdir, squash: false, remote: nil, branch: nil,
                 update: false, force: false)
      main_repository.check_clean

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

      last_commit = subrepo.make_subrepo_branch_for_local_commits

      unless last_commit
        if last_fetched_commit
          puts "Subrepo '#{subdir}' has no new commits to push."
        else
          warn "Nothing mapped"
        end
        return
      end

      message = "Push subrepo #{subdir}"

      subrepo.prepare_squashed_subrepo_branch_for_push(message: message) if squash

      split_branch_name = subrepo.split_branch_name
      force_flag = "--force" if force
      run_command "git push -q #{force_flag} #{remote.shellescape}" \
        " #{split_branch_name}:#{branch}"

      pushed_commit = repo.branches[split_branch_name].target.oid
      parent_commit = repo.head.target.oid

      config.commit = pushed_commit
      config.parent = parent_commit
      config.remote = remote if update
      run_command "git add -f -- #{config.file_name.shellescape}"
      run_command "git commit -q -m #{message.shellescape}"

      subrepo.remove_local_commits_branch
      puts "Subrepo '#{subdir}' pushed to '#{remote}' (#{branch})."
    end

    def run_branch_all
      main_repository.subrepos.each { |subdir| run_branch subdir }
    end

    def run_branch(subdir, force: false)
      main_repository.check_clean

      subrepo = sub_repository(subdir)
      if !force && subrepo.split_branch_exists?
        raise "Branch '#{subrepo.split_branch_name}' already exists." \
          " Use '--force' to override."
      end
      subrepo.make_subrepo_branch_for_local_commits

      puts "Created branch '#{subrepo.split_branch_name}'" \
        " and worktree '.git/tmp/subrepo/#{subdir}'."
    end

    def run_clone(remote, subdir = nil, branch: nil, method: nil, force: false)
      main_repository.check_clean

      subdir ||= guess_subdir_from_remote(remote)
      branch ||= "master"
      method ||= "merge"

      raise "You can't clone into an empty repository" if repo.empty?

      if !force && File.exist?(subdir)
        Dir.empty? subdir or raise "The subdir '#{subdir}' exists and is not empty."
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
        run_command "git rm -r #{subdir.shellescape}"
      end
      run_command "git read-tree --prefix=#{subdir.shellescape} -u #{last_fetched_commit}"

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

    def guess_subdir_from_remote(remote)
      guess = remote.sub(/\.git$/, "").sub(%r{/$}, "").sub(%r{.*/}, "")
      raise "Can't determine subdir from '#{remote}'." if guess.empty?

      guess
    end
  end
end
