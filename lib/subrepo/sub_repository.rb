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
      @last_fetched_commit ||= repo.ref(fetch_ref).target_id
    end

    def last_merged_commit
      @last_merged_commit ||=
        begin
          commit = config.commit
          commit = nil if commit == ""
          commit
        end
    end

    def split_branch_name
      @split_branch_name ||= "subrepo/#{subref}"
    end

    def fetch_ref
      @fetch_ref ||= "refs/subrepo/#{subref}/fetch"
    end

    def make_subrepo_branch_for_local_commits(squash: false)
      last_pushed_commit = config.parent

      mapped_commit = map_commits(last_pushed_commit)
      return unless mapped_commit

      run_command_in_worktree "git checkout #{split_branch_name}"
      run_command_in_worktree "git reset --hard #{mapped_commit}"
      if squash
        run_command_in_worktree "git reset --soft #{last_merged_commit}"
        run_command_in_worktree "git commit --reuse-message=#{mapped_commit}"
        mapped_commit = repo.branches[split_branch_name].target.oid
      end
      mapped_commit
    end

    def merge_subrepo_commits_into_main_repo(squash:, message:, edit:)
      validate_last_merged_commit_present_in_fetched_commits

      current_branch = `git rev-parse --abbrev-ref HEAD`.chomp
      config_name = config.file_name

      branch = config.branch
      last_local_commit = repo.head.target
      last_config_commit = `git log -n 1 --pretty=format:%H -- "#{config_name}"`

      if squash
        mapped_commit = map_commits(config.parent)
        run_command_in_worktree "git checkout #{split_branch_name}"
        run_command_in_worktree "git reset --hard #{mapped_commit}"
        run_command_in_worktree "git merge #{last_fetched_commit} --no-ff --no-edit -q"

        split_branch = repo.branches[split_branch_name]
        split_branch_commit = split_branch.target
        subtree = split_branch_commit.tree
        base_tree = last_local_commit.tree
        new_tree = graft_subrepo_tree(subdir_parts, base_tree, subtree)

        options = {}
        options[:tree] = new_tree
        options[:parents] = [last_local_commit]
        options[:message] = "WIP"
        new_commit_sha = Rugged::Commit.create(repo, options)

        run_command "git checkout -q #{current_branch}"
        run_command "git reset --hard #{new_commit_sha}"
        config.parent = last_config_commit
      else
        run_command "git rebase" \
          " --onto #{last_config_commit} #{last_merged_commit} #{last_fetched_commit}" \
          " --rebase-merges" \
          " -X subtree=\"#{subdir}\""

        rebased_head = `git rev-parse HEAD`.chomp
        run_command "git checkout -q #{current_branch}"
        run_command "git merge #{rebased_head} --no-ff --no-edit -q"

        config.parent = rebased_head
      end

      config.commit = last_fetched_commit
      run_command "git add -- \"#{config_name}\""

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

    def validate_last_merged_commit_present_in_fetched_commits
      walker = Rugged::Walker.new(repo)
      walker.push last_fetched_commit
      found = walker.to_a.any? { |commit| commit.oid == last_merged_commit }
      unless found
        raise "Last merged commit #{last_merged_commit} not found in fetched commits"
      end
    end

    def create_split_branch_if_needed
      return if repo.branches.exist? split_branch_name

      branch_commit = last_merged_commit || repo.head.target_id
      repo.branches.create split_branch_name, branch_commit
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
      @worktree_name ||= File.join(repo.path, "tmp/#{split_branch_name}")
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
    def map_commits(last_pushed_commit)
      create_split_branch_if_needed
      create_worktree_if_needed

      walker = Rugged::Walker.new(repo)
      walker.push repo.head.target_id
      walker.hide last_pushed_commit if last_pushed_commit

      commits = walker.to_a

      last_commit = nil

      commits.reverse_each do |commit|
        mapped_commit = map_commit(commit)
        last_commit = mapped_commit if mapped_commit
      end

      last_commit
    end

    def map_commit(commit)
      target_parents = calculate_target_parents(commit)
      target_tree = calculate_target_tree(commit, target_parents) or return

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

    def calculate_target_parents(commit)
      parents = commit.parents

      # Map parent commits
      target_parent_shas = parents.map do |parent|
        # TODO: Improve upon last_merged_commit as best guess
        commit_map.fetch parent.oid, last_merged_commit
      end.uniq.compact
      if commit_map[commit.oid]
        mapped_oid = commit_map[commit.oid]
        target_parent_shas << mapped_oid unless target_parent_shas.include? mapped_oid
      end
      target_parent_shas.map { |sha| repo.lookup sha }
    end

    def calculate_target_tree(commit, target_parents)
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
          commit_map[commit.oid] ||= first_target_parent.oid
          return
        end

        if first_target_parent
          rewritten_patch = diffs.first.patch
          target_patch = calculate_patch(rewritten_tree, first_target_parent.tree)
          if rewritten_patch != target_patch
            worktree_repo = Rugged::Repository.new(worktree_name)
            index = worktree_repo.index
            index.read_tree(first_target_parent.tree)
            worktree_repo.apply diffs.first, location: :index
            target_tree = worktree_repo.lookup index.write_tree(worktree_repo)
          end
        end
      end
      target_tree
    end

    def config_file_in_tree(tree)
      subtree = tree_in_subrepo(tree)
      subtree[".gitrepo"] if subtree
    end

    def commit_map
      @commit_map ||= full_commit_map
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

        config = config_from_blob_oid current[:oid]
        last_pushed_commit_oid = config["subrepo.parent"] or next
        last_merged_commit_oid = config["subrepo.commit"]

        remote_commit_tree = repo.lookup(last_merged_commit_oid).tree

        sub_walker = Rugged::Walker.new(repo)
        sub_walker.push last_pushed_commit_oid
        commit_map.each_key { |oid| sub_walker.hide oid }

        sub_walker.to_a.reverse_each do |sub_commit|
          sub_commit_tree = calculate_subtree(sub_commit)
          if sub_commit_tree.oid == remote_commit_tree.oid
            commit_map[sub_commit.oid] = last_merged_commit_oid
          end
        end

        last_pushed_commit = repo.lookup last_pushed_commit_oid
        last_pushed_commit_tree = calculate_subtree(last_pushed_commit)
        if last_pushed_commit_tree.oid == remote_commit_tree.oid
          commit_map[last_pushed_commit_oid] = last_merged_commit_oid
        end

        # FIXME: Only valid if current commit contains no other changes in
        # subrepo.
        commit_map[commit.oid] = last_merged_commit_oid
      end
      commit_map
    end

    def config_from_blob_oid(oid)
      tmp = Tempfile.new("config")
      tmp.write repo.lookup(oid).text
      tmp.close
      Rugged::Config.new(tmp.path)
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

    def graft_subrepo_tree(path_parts, base_tree, subrepo_tree)
      part, *rest = *path_parts

      builder = Rugged::Tree::Builder.new(repo)

      if part.nil?
        items = subrepo_tree.to_a
        config_item = base_tree[".gitrepo"]
        items << config_item if config_item
      else
        items = base_tree.to_a
        sub_item = items.find { |it| it[:name] == part }
        subtree = repo.lookup sub_item[:oid]
        sub_item[:oid] = graft_subrepo_tree(rest, subtree, subrepo_tree)
      end

      items.each { |it| builder << it }
      builder.write
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

    def run_command_in_worktree(command)
      Dir.chdir worktree_name do
        run_command command
      end
    end
  end
end
