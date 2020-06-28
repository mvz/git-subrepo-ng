# frozen_string_literal: true

require "rugged"

# Helper methods for repo-related steps
module Repo
  def initialize_empty_project(proj)
    create_directory proj
    cd proj do
      repo = Rugged::Repository.init_at(".")
      config = repo.config
      config["user.name"] = "Foo Bar"
      config["user.email"] = "foo@bar.net"
    end
  end

  def initialize_project(proj)
    initialize_empty_project(proj)
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

  def create_and_commit_file(proj, file)
    cd proj do
      repo = Rugged::Repository.new(".")
      write_file file, "stuff"
      index = repo.index
      index.add file
      index.write
      parents = if repo.head_unborn?
                  []
                else
                  [repo.head.target]
                end
      Rugged::Commit.create(repo,
                            tree: index.write_tree,
                            message: "Add #{file} in repo #{proj}",
                            parents: parents,
                            update_ref: "HEAD")
    end
  end

  def create_and_commit_file_in_subdir(proj, subdir:, file: "a_file")
    cd proj do
      repo = Rugged::Repository.new(".")
      create_directory subdir
      write_file "#{subdir}/#{file}", "stuff"
      index = repo.index
      index.add "#{subdir}/#{file}"
      index.write
      parents = if repo.head_unborn?
                  []
                else
                  [repo.head.target]
                end
      Rugged::Commit.create(repo,
                            tree: index.write_tree,
                            message: "Add #{subdir}/#{file} in repo #{proj}",
                            parents: parents,
                            update_ref: "HEAD")
    end
  end

  def update_and_commit_file_in_subdir(proj, subdir:, file: "a_file")
    cd proj do
      repo = Rugged::Repository.new(".")
      write_file "#{subdir}/#{file}", "new subrepo content"
      index = repo.index
      index.add "#{subdir}/#{file}"
      index.write
      Rugged::Commit.create(repo,
                            tree: index.write_tree,
                            message: "Update #{subdir}/#{file} in repo #{proj}",
                            parents: [repo.head.target],
                            update_ref: "HEAD")
    end
  end

  def empty_remote(remote)
    in_current_directory do
      Rugged::Repository.init_at(remote, :bare)
    end
  end

  def remote_commit_add(remote_path, file, contents, branch: nil)
    repo = Rugged::Repository.new(remote_path)
    oid = repo.write(contents, :blob)
    builder = Rugged::Tree::Builder.new(repo)
    builder << { type: :blob, name: file, oid: oid, filemode: 0o100644 }
    if repo.empty?
      parents = []
    else
      head_commit = repo.head.target
      head_commit.tree.each { |it| builder << it }
      parents = [head_commit]
    end
    ref = branch ? "refs/heads/#{branch}" : "HEAD"
    Rugged::Commit.create(repo,
                          tree: builder.write,
                          message: "Add #{file}",
                          parents: parents,
                          update_ref: ref)
  end

  def create_branch(repo_path, branch_name)
    repo = Rugged::Repository.new(repo_path)
    repo.branches.create(branch_name, "HEAD")
  end

  def merge_branch(repo_path, branch_name)
    repo = Rugged::Repository.new(repo_path)
    head_commit = repo.head.target
    branch_commit = repo.branches[branch_name].target
    index = repo.merge_commits(repo.head.target, branch_commit)
    Rugged::Commit.create(repo,
                          tree: index.write_tree(repo),
                          message: "Merge #{branch_name} into master",
                          parents: [head_commit, branch_commit],
                          update_ref: "HEAD")
  end

  def get_log_from_repo(repo_name)
    cd repo_name do
      `git log --graph --pretty=format:"%s" --abbrev-commit`
    end
  end
end

World Repo
