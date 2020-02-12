# frozen_string_literal: true

require "rugged"
require "tempfile"

module Subrepo
  # SubRepository, represents a subrepo
  class SubRepository
    include Commands
    attr_reader :main_repository, :subdir

    def initialize(main_repository, subdir)
      @main_repository = main_repository
      @subdir = subdir
    end

    # Map all commits that haven't been pushed yet
    def map_commits(last_pushed_commit, last_merged_commit)
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
        mapped_commit = map_commit(last_merged_commit, commit, commit_map)
        last_commit = mapped_commit if mapped_commit
      end
      last_commit
    end

    private

    def map_commit(last_merged_commit, commit, commit_map)
      parents = commit.parents

      # Map parent commits
      parent_shas = parents.map(&:oid)
      target_parent_shas = parent_shas.map do |sha|
        # TODO: Improve upon last_merged_commit as best guess
        commit_map.fetch sha, last_merged_commit
      end.uniq.compact
      target_parents = target_parent_shas.map { |sha| repo.lookup sha }
      rewritten_tree = calculate_subtree(commit)

      target_tree = rewritten_tree

      if parents.empty?
        return if rewritten_tree.entries.empty?
      else
        # TODO: Compare tree oids directly instead of doing a full diff
        # should be faster.
        diffs = parents.map do |parent|
          rewritten_parent_tree = calculate_subtree(parent)
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
          return
        end

        if first_target_parent
          rewritten_patch = diffs.first.patch
          target_patch = calculate_patch(rewritten_tree, first_target_parent.tree)
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
      new_commit_sha
    end

    def calculate_subtree(commit)
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

    def calculate_patch(rewritten_tree, target_parent_tree)
      target_diff = target_parent_tree.diff rewritten_tree
      target_diff.patch
    end

    def repo
      @repo ||= main_repository.repo
    end
  end
end
