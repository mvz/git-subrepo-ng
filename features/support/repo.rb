# frozen_string_literal: true

require "rugged"

# Helper methods for repo-related steps
module Repo
  def initialize_project(proj)
    create_directory proj
    cd proj do
      repo = Rugged::Repository.init_at(".")
      write_file "README", "Hi!"
      index = repo.index
      index.add "README"
      index.write
      Rugged::Commit.create(repo, tree: index.write_tree, message: "Initial commit",
                            parents: [], update_ref: "HEAD")
    end
  end

  def subdir_with_commits_in_project(proj, subdir:)
    cd proj do
      repo = Rugged::Repository.new(".")
      create_directory subdir
      write_file "#{subdir}/a_file", "stuff"
      index = repo.index
      index.add "#{subdir}/a_file"
      index.write
      Rugged::Commit.create(repo, tree: index.write_tree, message: "Add stuff in #{subdir}",
                            parents: [repo.head.target], update_ref: "HEAD")
    end
  end

  def empty_remote(remote)
    in_current_directory do
      Rugged::Repository.init_at(remote, :bare)
    end
  end
end

World Repo
