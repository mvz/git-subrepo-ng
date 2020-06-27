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
      subrepo.local_commits.reverse_each do |commit|
        next unless config_changed?(commit)

        config = config_for_commit(commit)
        pushed_commit_oid = config["subrepo.parent"] or next
        merged_commit_oid = config["subrepo.commit"]
        remote_commit_tree = repo.lookup(merged_commit_oid).tree

        map_dependent_commits(pushed_commit_oid, merged_commit_oid, remote_commit_tree)

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

    def map_dependent_commits(pushed_commit_oid, merged_commit_oid, remote_commit_tree)
      sub_walker = Rugged::Walker.new(repo)
      sub_walker.push pushed_commit_oid
      @mapping.each_key { |oid| sub_walker.hide oid unless oid == pushed_commit_oid }

      dependent_commits = sub_walker.to_a

      dependent_commits.reverse_each do |sub_commit|
        sub_commit_tree = subrepo.calculate_subtree(sub_commit)

        if sub_commit.parents.empty? && sub_commit_tree.entries.empty?
          @mapping[sub_commit.oid] = nil
          next
        end

        # TODO: Maybe this section only makes sense for the first commit we handle?
        # Compare trees for earlier commits with the current tree
        if sub_commit_tree.oid == remote_commit_tree.oid
          @mapping[sub_commit.oid] = merged_commit_oid
          next
        end

        # Compare trees for earlier commits with their mapped parents' trees,
        # and with their mapped parents' children's trees
        sub_commit.parents.each do |sub_parent|
          mapped_parent_oid = @mapping[sub_parent.oid]
          next unless mapped_parent_oid

          remote_children = remote_child_map[mapped_parent_oid] || []
          mapped = remote_children.find do |remote_child|
            if sub_commit_tree.oid == remote_child.tree.oid
              @mapping[sub_commit.oid] = remote_child.oid
              true
            end
          end
          break if mapped

          sub_parent_tree = subrepo.calculate_subtree(sub_parent)
          if sub_commit_tree.oid == sub_parent_tree.oid
            @mapping[sub_commit.oid] = mapped_parent_oid
            break
          end
        end
      end
    end

    def remote_child_map
      @remote_child_map ||=
        begin
          child_map = {}
          subrepo.remote_commits.each do |commit|
            commit.parents.each do |parent|
              child_map[parent.oid] ||= []
              child_map[parent.oid] << commit
            end
          end
          child_map
        end
    end

    def config_changed?(commit)
      parent = commit.parents[0]
      return false unless parent

      current = config_blob_info_for_commit(commit)
      return false unless current

      previous = config_blob_info_for_commit(parent)
      return true unless previous

      current[:oid] != previous[:oid]
    end

    def config_blob_info_for_commit(commit)
      subrepo.config_file_in_tree(commit.tree)
    end

    def config_for_commit(commit)
      config_blob = config_blob_info_for_commit(commit)
      config_from_blob_oid config_blob[:oid]
    end

    def config_from_blob_oid(oid)
      tmp = Tempfile.new("config")
      tmp.write repo.lookup(oid).text
      tmp.close
      Rugged::Config.new(tmp.path)
    end
  end
end
