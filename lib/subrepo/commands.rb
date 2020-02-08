# frozen_string_literal: true

require "open3"
require "rugged"
require "tempfile"

require "subrepo/version"
require "subrepo/config"
require "subrepo/runner"

module Subrepo
  # Entry point for each of the subrepo commands
  module Commands
    module_function

    def command_status(recursive: false)
      repo = Rugged::Repository.new(".")
      tree = repo.head.target.tree
      subrepos = []
      tree.walk_blobs do |path, blob|
        next if blob[:name] != ".gitrepo"

        unless recursive
          next if subrepos.any? { |it| path.start_with? it }
        end
        subrepos << path
      end

      puts "#{subrepos.count} subrepos:"
      subrepos.each do |it|
        puts "Git subrepo '#{it.chop}':"
      end
    end

    def command_config(subdir, option:, value:, force: false)
      subdir or raise "Command 'config' requires arg 'subdir'."
      option or raise "Command 'config' requires arg 'option'."

      config = Config.new(subdir)
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

    def command_fetch(subdir, remote: nil)
      subdir or raise "Command 'fetch' requires arg 'subdir'."

      config = Config.new(subdir)
      remote ||= config.remote
      branch = config.branch
      last_merged_commit = config.commit

      last_fetched_commit = perform_fetch(subdir, remote, branch, last_merged_commit)
      if last_fetched_commit == last_merged_commit
        puts "No change"
      else
        puts "Fetched '#{subdir}' from '#{remote}' (#{branch})."
      end
    end

    def command_merge(subdir, squash:, message: nil, edit: false)
      subdir or raise "Command 'merge' requires arg 'subdir'."
      current_branch = `git rev-parse --abbrev-ref HEAD`.chomp
      config = Config.new(subdir)
      branch = config.branch
      last_merged_commit = config.commit

      repo = Rugged::Repository.new(".")

      last_local_commit = repo.head.target.oid
      config_name = config.file_name
      last_config_commit = `git log -n 1 --pretty=format:%H -- "#{config_name}"`

      refs_subrepo_fetch = "refs/subrepo/#{subdir}/fetch"
      last_fetched_commit = `git rev-parse #{refs_subrepo_fetch}`.chomp

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

    def command_pull(subdir, squash:, remote: nil)
      Runner.new.pull(subdir, squash: squash, remote: remote)
    end

    def command_push(subdir, remote: nil, branch: nil, force: false)
      Runner.new.push(subdir, remote: remote, branch: branch, force: force)
    end

    def command_init(subdir, remote: nil, branch: nil, method: nil)
      Runner.new.init(subdir, remote: remote, branch: branch, method: method)
    end

    def command_clone(remote, subdir = nil, branch: nil, method: nil)
      Runner.new.clone(remote, subdir, branch: branch, method: method)
    end

    def map_commits(repo, subdir, last_pushed_commit, last_merged_commit)
      # Walk all commits that haven't been pushed yet
      walker = Rugged::Walker.new(repo)
      walker.push repo.head.target_id
      if last_pushed_commit
        walker.hide last_pushed_commit
        commit_map = { last_pushed_commit => last_merged_commit }
      else
        commit_map = {}
      end

      commits = walker.to_a

      last_commit = nil

      commits.reverse_each do |commit|
        parents = commit.parents

        # Map parent commits
        parent_shas = parents.map(&:oid)
        target_parent_shas = parent_shas.map do |sha|
          # TODO: Improve upon last_merged_commit as best guess
          commit_map.fetch sha, last_merged_commit
        end.uniq.compact
        target_parents = target_parent_shas.map { |sha| repo.lookup sha }
        rewritten_tree = calculate_subtree(repo, subdir, commit)

        target_tree = rewritten_tree

        if parents.empty?
          next if rewritten_tree.entries.empty?
        else
          # TODO: Compare tree oids directly instead of doing a full diff
          # should be faster.
          diffs = parents.map do |parent|
            rewritten_parent_tree = calculate_subtree(repo, subdir, parent)
            rewritten_parent_tree.diff rewritten_tree
          end

          first_target_parent = target_parents.first

          # If the commit tree is no different from the first parent, this is
          # either:
          #
          # - a regular commit that makes no changes to the subrepo, or
          # - a merge that has no effect on the mainline
          #
          # Otherwise, if there is only one target parent, and at least one of
          # the original diffs is empty, then this would become an empty merge
          # commit.
          #
          # Finally, if the rewritten_tree is identical to the single target
          # parent tree. this would also become an empty regular commit.
          #
          # In all of these cases, map this commit to the target parent and
          # skip to the next commit.
          if diffs.first.none? ||
              target_parents.one? && diffs.any?(&:none?) ||
              target_parents.one? && rewritten_tree.oid == first_target_parent.tree.oid
            commit_map[commit.oid] = first_target_parent.oid
            next
          end

          if first_target_parent
            rewritten_patch = diffs.first.patch
            target_parent_tree = first_target_parent.tree
            target_diff = target_parent_tree.diff rewritten_tree
            target_patch = target_diff.patch
            if rewritten_patch != target_patch
              run_command "git checkout -q #{first_target_parent.oid}"
              patch = Tempfile.new("subrepo-patch")
              patch.write rewritten_patch
              patch.close
              run_command "git apply --3way #{patch.path}"
              patch.unlink
              target_tree = `git write-tree`.chomp
              run_command "git reset -q --hard"
            end
          end
        end

        # Commit has multiple mapped parents or is non-empty: We should
        # create it in the target branch too.
        options = {}
        options[:tree] = target_tree
        options[:author] = commit.author
        options[:parents] = target_parents
        options[:message] = commit.message

        new_commit_sha = Rugged::Commit.create(repo, options)
        commit_map[commit.oid] = new_commit_sha
        last_commit = new_commit_sha
      end
      last_commit
    end

    def calculate_subtree(repo, subdir, commit)
      # Calculate part of the tree that is in the subrepo
      subtree_oid = commit.tree[subdir]&.fetch(:oid)
      builder = Rugged::Tree::Builder.new(repo)

      if subtree_oid
        subtree = repo.lookup subtree_oid

        # Filter out .gitrepo
        subtree.reject { |it| it[:name] == ".gitrepo" }.each { |it| builder << it }
      end

      rewritten_tree_sha = builder.write
      repo.lookup rewritten_tree_sha
    end

    def perform_fetch(subdir, remote, branch, _last_merged_commit)
      remote_commit = `git ls-remote --no-tags \"#{remote}\" \"#{branch}\"`
      return false if remote_commit.empty?

      run_command "git fetch -q --no-tags \"#{remote}\" \"#{branch}\""
      new_commit = `git rev-parse FETCH_HEAD`.chomp
      refs_subrepo_fetch = "refs/subrepo/#{subdir}/fetch"
      run_command "git update-ref #{refs_subrepo_fetch} #{new_commit}"
      new_commit
    end

    def run_command(command)
      _out, _err, status = Open3.capture3 command
      status == 0 or raise "Command failed"
    end
  end
end
