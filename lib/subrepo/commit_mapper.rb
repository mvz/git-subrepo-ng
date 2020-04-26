# frozen_string_literal: true

module Subrepo
  # Create a map between commits in the main repo and the subrepo's remote
  class CommitMapper
    def self.map_commits(subrepo)
      new(subrepo).map_commits
    end

    def initialize(subrepo)
      @subrepo = subrepo
      @repo = subrepo.repo
      @mapping = {}
    end

    def map_commits
      map_all_commits
      mapping
    end

    private

    attr_reader :subrepo, :repo, :mapping

    def map_all_commits
      all_commits.reverse_each do |commit|
        parent = commit.parents[0] or next
        current = subrepo.config_file_in_tree(commit.tree) or next

        previous = subrepo.config_file_in_tree(parent.tree)
        next if previous && current[:oid] == previous[:oid]

        config = config_from_blob_oid current[:oid]
        pushed_commit_oid = config["subrepo.parent"] or next
        merged_commit_oid = config["subrepo.commit"]

        remote_commit_tree = repo.lookup(merged_commit_oid).tree

        sub_walker = Rugged::Walker.new(repo)
        sub_walker.push pushed_commit_oid
        # TODO: Maybe make sure we don't hide pushed_commit_oid
        @mapping.each_key { |oid| sub_walker.hide oid }

        dependent_commits = sub_walker.to_a

        dependent_commits.reverse_each do |sub_commit|
          sub_commit_tree = subrepo.calculate_subtree(sub_commit)

          # TODO: Maybe this section only makes sense for the first commit we handle?
          # Compare trees for earlier commits with the current tree
          if sub_commit_tree.oid == remote_commit_tree.oid
            @mapping[sub_commit.oid] = merged_commit_oid
            next
          end

          # TODO: Also check children of the parents' mapped commits
          # Compare trees for earlier commits with their parent trees
          sub_commit.parents.each do |sub_parent|
            mapped_parent_oid = @mapping[sub_parent.oid]
            next unless mapped_parent_oid

            sub_parent_tree = subrepo.calculate_subtree(sub_parent)
            next unless sub_commit_tree.oid == sub_parent_tree.oid

            @mapping[sub_commit.oid] = mapped_parent_oid
            break
          end
        end

        last_pushed_commit = repo.lookup pushed_commit_oid
        last_pushed_commit_tree = subrepo.calculate_subtree(last_pushed_commit)
        if last_pushed_commit_tree.oid == remote_commit_tree.oid
          @mapping[pushed_commit_oid] = merged_commit_oid
        end

        # Map the commit containing a change to .gitrepo.
        # If its subtree is equal to remote tree, we can safely map it.
        # Otherwise, if it has one parent, assume it's a squash merge commit.
        if commit.parents.count == 1 ||
            subrepo.calculate_subtree(commit).oid == remote_commit_tree.oid
          @mapping[commit.oid] = merged_commit_oid
        end
      end
    end

    def all_commits
      walker = Rugged::Walker.new(repo)
      walker.push repo.head.target_id
      walker.to_a
    end

    def config_from_blob_oid(oid)
      tmp = Tempfile.new("config")
      tmp.write repo.lookup(oid).text
      tmp.close
      Rugged::Config.new(tmp.path)
    end
  end
end
