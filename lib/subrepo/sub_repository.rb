# frozen_string_literal: true

require "rugged"
require "tempfile"
require "fileutils"

module Subrepo
  # SubRepository, represents a subrepo
  class SubRepository
    include Commands
    attr_reader :main_repository, :subdir

    def initialize(main_repository, subdir)
      @main_repository = main_repository
      @subdir = subdir
    end

    def perform_fetch(remote, branch)
      remote_commit = `git ls-remote --no-tags \"#{remote}\" \"#{branch}\"`
      return false if remote_commit.empty?

      run_command "git fetch -q --no-tags \"#{remote}\" \"#{branch}\""
      new_commit = `git rev-parse FETCH_HEAD`.chomp

      run_command "git update-ref #{fetch_ref} #{new_commit}"
      new_commit
    end

    def last_fetched_commit
      repo.ref(fetch_ref).target_id
    end

    def split_branch_name
      @split_branch_name ||= "subrepo/#{subref}"
    end

    def fetch_ref
      @fetch_ref ||= "refs/subrepo/#{subref}/fetch"
    end

    def make_local_commits_branch(squash: false)
      last_merged_commit = config.commit
      last_pushed_commit = config.parent
      last_merged_commit = nil if last_merged_commit == ""

      unless repo.branches.exist? split_branch_name
        branch_commit = last_merged_commit || repo.head.target_id

        repo.branches.create split_branch_name, branch_commit
      end

      create_worktree_if_needed

      Dir.chdir worktree_name do
        mapped_commit = map_commits(last_pushed_commit, last_merged_commit)
        return unless mapped_commit

        run_command "git checkout #{split_branch_name}"
        run_command "git reset --hard #{mapped_commit}"
        if squash
          run_command "git reset --soft #{last_merged_commit}"
          run_command "git commit --reuse-message=#{mapped_commit}"
          mapped_commit = repo.branches[split_branch_name].target.oid
        end
        mapped_commit
      end
    end

    def remove_local_commits_branch
      remove_worktree_if_needed
      repo.branches.delete split_branch_name if repo.branches.exist? split_branch_name
    end

    def remove_fetch_ref
      repo.references.delete fetch_ref
    end

    def config
      @config ||= Config.new(subdir)
    end

    private

    def subref
      @subref ||= subdir
        .gsub(%r{(^|/)\.}, "\\1%2e") # dot at start or after /
        .gsub(%r{\.lock($|/)}, "%2elock\\1") # .lock at end or before /
        .gsub(/\.\./, "%2e%2e") # pairs of consecutive dots
        .gsub(/%2e\./, "%2e%2e") # odd numbers of dots
        .gsub(/[\000-\037\177]/) { |ch| hexify ch } # ascii control characters
        .gsub(/[ ~^:?*\[\n\\]/) { |ch| hexify ch } # other forbidden characters
        .gsub(%r{//+}, "/") # consecutive slashes
        .gsub(%r{(^/|/$)}, "") # slashes at start or end
        .gsub(/\.$/, "%2e") # dot at end
        .gsub(/@{/, "%40{") # sequence @{
        .sub(/^@$/, "%40") # single @
    end

    def worktree_name
      @worktree_name ||= ".git/tmp/#{split_branch_name}"
    end

    def create_worktree_if_needed
      return if worktree_exists?

      run_command "git worktree add \"#{worktree_name}\" \"#{split_branch_name}\""
    end

    def remove_worktree_if_needed
      return if !worktree_exists?

      FileUtils.remove_entry_secure worktree_name
      run_command "git worktree prune"
    end

    def worktree_exists?
      worktrees = `git worktree list`
      worktrees.include? worktree_name
    end

    # Map all commits that haven't been pushed yet
    def map_commits(last_pushed_commit, last_merged_commit)
      walker = Rugged::Walker.new(repo)
      walker.push repo.head.target_id
      if last_pushed_commit
        walker.hide last_pushed_commit
        commit_map = full_commit_map
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

    def map_commit(last_merged_commit, commit, commit_map)
      target_parents = calculate_target_parents(commit, commit_map, last_merged_commit)
      target_tree = calculate_target_tree(commit, target_parents, commit_map) or return

      # Check if there were relevant changes
      if last_merged_commit
        old_tree_oid = repo.lookup(last_merged_commit).tree.oid
        new_tree_oid = target_tree.oid
        return if old_tree_oid == new_tree_oid
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

    def calculate_target_parents(commit, commit_map, last_merged_commit)
      parents = commit.parents

      # Map parent commits
      target_parent_shas = parents.map do |parent|
        # TODO: Improve upon last_merged_commit as best guess
        commit_map.fetch parent.oid, last_merged_commit
      end.uniq.compact
      target_parent_shas.map { |sha| repo.lookup sha }
    end

    def calculate_target_tree(commit, target_parents, commit_map)
      parents = commit.parents
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
            target_tree = repo.lookup `git write-tree`.chomp
            run_command "git reset -q --hard"
          end
        end
      end
      target_tree
    end

    def config_file_in_tree(tree)
      subtree = tree_in_subrepo(tree)
      subtree[".gitrepo"] if subtree
    end

    def full_commit_map
      commit_map = {}
      walker = Rugged::Walker.new(repo)
      walker.push repo.head.target_id
      walker.to_a.reverse_each do |commit|
        parent = commit.parents[0] or next
        current = config_file_in_tree(commit.tree) or next

        previous = config_file_in_tree(parent.tree)
        next if previous && current[:oid] == previous[:oid]

        tmp = Tempfile.new("config")
        tmp.write repo.lookup(current[:oid]).text
        tmp.close
        config = Rugged::Config.new(tmp.path)

        last_pushed_commit = config["subrepo.parent"] or next
        last_merged_commit = config["subrepo.commit"]
        commit_map[last_pushed_commit] = last_merged_commit
        # FIXME: Only valid if current commit contains no other changes in
        # subrepo.
        commit_map[commit.oid] = last_merged_commit
      end
      commit_map
    end

    def calculate_subtree(commit)
      subtree = tree_in_subrepo(commit.tree)
      builder = Rugged::Tree::Builder.new(repo)
      # Filter out .gitrepo
      subtree&.reject { |it| it[:name] == ".gitrepo" }&.each { |it| builder << it }

      rewritten_tree_sha = builder.write
      repo.lookup rewritten_tree_sha
    end

    def calculate_patch(rewritten_tree, target_parent_tree)
      target_diff = target_parent_tree.diff rewritten_tree
      target_diff.patch
    end

    # Calculate part of tree that is in the subrepo
    def tree_in_subrepo(main_tree)
      subdir_parts.inject(main_tree) do |tree, part|
        subtree_oid = tree[part]&.fetch(:oid) or break
        repo.lookup subtree_oid
      end
    end

    def subdir_parts
      @subdir_parts ||= subdir.split(%r{/+})
    end

    def repo
      @repo ||= main_repository.repo
    end

    def hexify(char)
      format("%%%<ord>02x", ord: char.ord)
    end
  end
end
