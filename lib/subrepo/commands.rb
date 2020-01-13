# frozen_string_literal: true

require "tempfile"
require "rugged"
require "subrepo/version"
require "subrepo/config"

module Subrepo
  # Entry point for each of the subrepo commands
  module Commands
    module_function

    def command_fetch(subdir, remote: nil)
      config = Config.new(subdir)
      remote ||= config.remote
      branch = config.branch
      last_merged_commit = config.commit

      remote_commit = `git ls-remote --no-tags \"#{remote}\" \"#{branch}\"`
      if remote_commit.empty?
        puts "Branch #{branch} not on remote yet"
        return false
      end
      system "git fetch -q --no-tags \"#{remote}\" \"#{branch}\""
      new_commit = `git rev-parse FETCH_HEAD`.chomp
      puts "Fetched #{new_commit}"
      puts "No change" if new_commit == last_merged_commit
      refs_subrepo_fetch = "refs/subrepo/#{subdir}/fetch"
      system "git update-ref #{refs_subrepo_fetch} #{new_commit}"
      true
    end

    def command_merge(subdir)
      current_branch = `git rev-parse --abbrev-ref HEAD`.chomp
      config = Config.new(subdir)
      branch = config.branch
      last_merged_commit = config.commit

      config_name = config.file_name

      last_local_commit = `git log -n 1 --pretty=format:%H -- "#{config_name}"`
      refs_subrepo_fetch = "refs/subrepo/#{subdir}/fetch"
      last_fetched_commit = `git rev-parse #{refs_subrepo_fetch}`.chomp

      if last_fetched_commit == last_merged_commit
        warn "Nothing to do"
        return
      end

      command = "git rebase" \
        " --onto #{last_local_commit} #{last_merged_commit} #{last_fetched_commit}" \
        " --rebase-merges" \
        " -X subtree=#{subdir}"

      system command

      rebased_head = `git rev-parse HEAD`.chomp
      system "git checkout -q #{current_branch}"
      system "git merge #{rebased_head} --no-ff --no-edit" \
        " -q -m \"Subrepo-merge #{subdir}/#{branch} into #{current_branch}\""

      config.commit = last_fetched_commit
      config.parent = rebased_head
      system "git add \"#{config_name}\""
      system "git commit -q --amend --no-edit"
    end

    def command_pull(subdir, remote: nil)
      command_fetch(subdir, remote: remote)
      command_merge(subdir)
    end

    def command_push(subdir, remote: nil, branch: nil)
      fetched = command_fetch(subdir, remote: remote)

      repo = Rugged::Repository.new(".")

      config = Config.new(subdir)

      remote ||= config.remote
      branch ||= config.branch
      last_merged_commit = config.commit
      last_pushed_commit = config.parent

      if fetched
        refs_subrepo_fetch = "refs/subrepo/#{subdir}/fetch"
        last_fetched_commit = repo.ref(refs_subrepo_fetch).target_id
        last_fetched_commit == last_merged_commit or
          raise "There are new changes upstream, you need to pull first."
      end

      split_branch_name = "subrepo-#{subdir}"
      if repo.branches.exist? split_branch_name
        raise "It seems #{split_branch_name} already exists. Remove it first"
      end

      current_branch_name = `git rev-parse --abbrev-ref HEAD`.chomp

      last_commit = map_commits(repo, subdir, last_pushed_commit, last_merged_commit)

      unless last_commit
        if fetched
          warn "No changes to push"
        else
          warn "Nothing mapped"
        end
        return
      end

      repo.branches.create split_branch_name, last_commit
      system "git push \"#{remote}\" #{split_branch_name}:#{branch}"
      pushed_commit = last_commit

      system "git checkout #{current_branch_name}"
      system "git reset --hard"
      system "git branch -D #{split_branch_name}"
      parent_commit = `git rev-parse HEAD`.chomp

      config.commit = pushed_commit
      config.parent = parent_commit
      system "git add -f -- #{config.file_name}"
      system "git commit -m \"Push subrepo #{subdir}\""
    end

    def command_init(subdir, remote:, branch:)
      repo = Rugged::Repository.new(".")

      File.exist? subdir or raise "The subdir '#{subdir} does not exist."
      config = Config.new(subdir)
      config_name = config.file_name
      File.exist? config_name and
        raise "The subdir '#{subdir}' is already a subrepo."
      last_subdir_commit = `git log -n 1 --pretty=format:%H -- "#{subdir}"`.chomp
      last_subdir_commit.empty? and
        raise "The subdir '#{subdir}' is not part of this repo."

      config.create(remote, branch)

      index = repo.index
      index.add config_name
      index.write
      Rugged::Commit.create(repo, tree: index.write_tree,
                            message: "Initialize subrepo #{subdir}",
                            parents: [repo.head.target], update_ref: "HEAD")
    end

    def map_commits(repo, subdir, last_pushed_commit, last_merged_commit)
      last_merged_commit = nil if last_merged_commit == ""

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

        parent_map = parent_shas.map { |sha|
          mapped = commit_map.fetch sha, last_merged_commit
          [sha, mapped]
        }.to_h

        if parents.empty?
          next if rewritten_tree.entries.empty?
          commit_tree = rewritten_tree
        else
          diffs = parents.map do |parent|
            rewritten_parent_tree = calculate_subtree(repo, subdir, parent)
            rewritten_parent_tree.diff rewritten_tree
          end

          # If commit tree is no different from the first parent, this is
          # either a regular commit that makes no changes to the subrepo, or a
          # merge that has no effect on the mainline. Map this commit to the
          # target parent and skip to the next commit.
          if diffs.first.none?
            target_parent = target_parents.first
            commit_map[commit.oid] = target_parent.oid if target_parent
            next
          end

          # If there is only one target parent, and at least one of the
          # original diffs is empty, this would be an empty merge commit
          # (regular empty commits have been filtered out above).
          # Map this commit to the target parent and skip to the next commit.
          if target_parents.one? && diffs.any?(&:none?)
            target_parent = target_parents.first
            commit_map[commit.oid] = target_parent.oid
            next
          end

          if target_parents.any?
            # There should be something to commit at this point, and there's a
            # target tree to commit agains.
            #
            # Now, apply source diff as a patch to the target tree.

            target_diff = target_parents.first.diff rewritten_tree
            if target_diff.patch == diffs.first.patch
              # Take a shortcut if patching the target tree would result in the
              # same rewritten tree.
              commit_tree = rewritten_tree
            else
              # Do the actual patching
              #
              # When Repository#apply is in a released version of rugged, we
              # can do this:
              #
              #    index = repo.index
              #    index.read_tree(target_parents.first.tree)
              #    repo.apply diffs.first, location: :index
              #    target_tree = index.write_tree

              system "git checkout -q #{target_parents.first.oid}"
              patch = Tempfile.new("subrepo-patch")
              patch.write diffs.first.patch
              patch.close
              result = system "git apply --cached #{patch.path}"
              unless result
                raise "Unable to apply patch -- aborting"
              end
              patch.unlink
              target_tree = `git write-tree`.chomp
              system "git reset --hard HEAD"

              # Check if commit would be
              # * an empty solo-commit, or
              # * a merge merging in no changes
              # This is similar to the checks above, but now with a new diff.
              target_diff = target_parents.first.diff target_tree
              if target_diff.none?
                target_parent = target_parents.first
                commit_map[commit.oid] = target_parent.oid
                next
              end

              commit_tree = target_tree
            end
          else
            commit_tree = rewritten_tree
          end
        end

        # Commit has multiple mapped parents or is non-empty: We should
        # create it in the target branch too.
        options = {}
        options[:tree] = commit_tree
        options[:author] = commit.author
        options[:committer] = commit.committer
        options[:parents] = target_parents
        options[:message] = commit.message

        puts "Committing #{commit.summary}"

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
        subtree.select { |it| it[:name] != ".gitrepo" }.each { |it| builder << it }
      end

      rewritten_tree_sha = builder.write
      repo.lookup rewritten_tree_sha
    end
  end
end
