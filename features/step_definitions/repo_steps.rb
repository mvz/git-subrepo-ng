# frozen_string_literal: true

Given "I have an existing git project named {string}" do |proj|
  initialize_project proj
  @main_repo = proj
end

Given "I have an empty git project named {string}" do |proj|
  initialize_empty_project proj
  @main_repo = proj
end

Given "I have an empty remote named {string}" do |remote|
  empty_remote(remote)
  @remote = remote
end

Given "I have a remote named {string} with some commits" do |remote|
  empty_remote(remote)
  @remote = remote
  full_remote = expand_path @remote
  remote_commit_add(full_remote, "this_file", "stuff")
  remote_commit_add(full_remote, "other_file", "more stuff")
end

When "I (have )create(d) and commit(ted) {string} in the remote" do |file|
  full_remote = expand_path @remote
  remote_commit_add(full_remote, file, "stuff")
end

When "I (have )update(d) and commit(ted) {string} in the remote" do |file|
  repo = Rugged::Repository.new expand_path(@remote)
  index = repo.index
  index.read_tree(repo.head.target.tree)
  new_blob_oid = repo.write("new remote content", :blob)
  index.add path: file, oid: new_blob_oid, mode: 0o100644
  Rugged::Commit.create(repo, tree: index.write_tree,
                        message: "Update #{file} in remote #{@remote}",
                        parents: [repo.head.target], update_ref: "HEAD")
end

When "I (have )update(d) and commit(ted) {string} in the subrepo" do |file|
  update_and_commit_file_in_subdir(@main_repo, subdir: @subrepo, file: file)
end

When "I add a new commit to the subrepo" do
  cd @main_repo do
    repo = Rugged::Repository.new(".")
    write_file "#{@subrepo}/other_file", "more stuff"

    index = repo.index
    index.add_all
    index.write
    Rugged::Commit.create(repo, tree: index.write_tree,
                          message: "Add more stuff in subrepo #{@subrepo}",
                          parents: [repo.head.target], update_ref: "HEAD")
  end
end

When "I add a new commit to the remote" do
  repo = Rugged::Repository.new expand_path(@remote)
  index = repo.index
  index.read_tree(repo.head.target.tree)
  new_blob_oid = repo.write("new content", :blob)
  index.add path: "another_file", oid: new_blob_oid, mode: 0o100644
  Rugged::Commit.create(repo, tree: index.write_tree,
                        message: "Add another_file in remote #{@remote}",
                        parents: [repo.head.target], update_ref: "HEAD")
end

When "I create a branch with some commits in the main project" do
  cd @main_repo do
    `git checkout -q -b unrelated-branch`
    write_file "another_main_file", "stuff"
    `git add -A`
    `git commit -am "Working"`
    write_file "yet_another", "more stuff"
    `git add -A`
    `git commit -am "More working"`
    `git checkout -q master`
  end
end

When "I create a branch with commits for {string} in the main project" do |file|
  cd @main_repo do
    `git checkout -q -b unrelated-branch`
    write_file file, "stuff"
    `git add -A`
    `git commit -am "Add #{file}"`
    write_file file, "more stuff"
    `git add -A`
    `git commit -am "Update #{file}"`
    `git checkout -q master`
  end
end

When "I create a branch with commits for {string} in the subrepo" do |file|
  cd @main_repo do
    `git checkout -q -b subrepo-branch`
  end
  create_and_commit_file_in_subdir(@main_repo, subdir: @subrepo, file: file)
  update_and_commit_file_in_subdir(@main_repo, subdir: @subrepo, file: file)
  cd @main_repo do
    `git checkout -q master`
  end
end

When "I (have )create(d) a branch with commits for {string} in the remote" do |file|
  full_remote = expand_path @remote
  branch_name = "#{file}-branch"
  create_branch(full_remote, branch_name)
  remote_commit_add(full_remote, file, "stuff", branch: branch_name)
end

When "I merge in the main project branch" do
  cd @main_repo do
    # NOTE: Explicit message given to ensure uniform result across git
    # versions. The explicit message can be removed once git 2.28 is commonly
    # used.
    `git merge --no-ff unrelated-branch -m "Merge branch 'unrelated-branch' into master"`
  end
end

When "I merge in the subrepo branch" do
  cd @main_repo do
    # NOTE: Explicit message given to ensure uniform result across git
    # versions. The explicit message can be removed once git 2.28 is commonly
    # used.
    `git merge --no-ff subrepo-branch -m "Merge branch 'subrepo-branch' into master"`
  end
end

When "I merge the branch for {string} in the remote" do |file|
  full_remote = expand_path @remote
  branch_name = "#{file}-branch"
  merge_branch(full_remote, branch_name)
end

When "I (have )commit(ted) a new file {string}" do |file|
  create_and_commit_file(@main_repo, file)
end

When "I (have )commit(ted) a new file {string} in subdirectory {string}" do |file, subdir|
  create_and_commit_file_in_subdir(@main_repo, subdir: subdir, file: file)
end

When "I commit a new file {string} in the subrepo" do |file|
  create_and_commit_file_in_subdir(@main_repo, subdir: @subrepo, file: file)
end

When "I resolve the merge conflict with merged content" do
  expect(@error).not_to be_nil
  cd @main_repo do
    cd ".git/tmp/subrepo/#{@subrepo}" do
      status = `git status --porcelain`.chomp
      expect(status).to start_with "UU "
      file = status[3..]
      write_file "#{@subrepo}/#{file}", "merged content for #{file}"
      `git add #{file}`
      `git commit --no-edit`
    end
  end
end

When "I resolve the merge conflict with local content" do
  expect(@error).not_to be_nil
  cd @main_repo do
    cd ".git/tmp/subrepo/#{@subrepo}" do
      status = `git status --porcelain`.chomp
      expect(status).to start_with "UU "
      file = status[3..]
      `git checkout -q --ours #{file}`
      `git add #{file}`
      `git commit --no-edit`
    end
  end
end

When "I resolve the merge conflict with remote content" do
  expect(@error).not_to be_nil
  cd @main_repo do
    cd ".git/tmp/subrepo/#{@subrepo}" do
      status = `git status --porcelain`.chomp
      expect(status).to start_with "UU "
      file = status[3..]
      `git checkout -q --theirs #{file}`
      `git add #{file}`
      `git commit --no-edit`
    end
  end
end

Then "the subrepo and the remote should have the same contents" do
  repo = Rugged::Repository.new expand_path(@remote)
  tree = repo.head.target.tree
  subrepo = expand_path @subrepo, @main_repo
  expected_entries = Dir.new(subrepo).entries - %w(. .. .gitrepo)
  subrepo_entries = tree.entries.map { |it| it[:name] }
  expect(subrepo_entries).to match_array expected_entries
  tree.entries.each do |entry|
    blob = repo.lookup entry[:oid]
    expect(blob.text).to eq File.read(File.join(subrepo, entry[:name]))
  end
end

Then "the remote's log should equal:" do |string|
  log = get_log_from_repo(@remote)
  expect(log).to eq string
end

Then "the project's log should equal:" do |string|
  log = get_log_from_repo(@main_repo)
  expect(log).to eq string
end

Then "the subrepo configuration should contain the latest commit and parent" do
  remote_repo = Rugged::Repository.new expand_path(@remote)
  repo = Rugged::Repository.new expand_path(@main_repo)
  subrepo = expand_path @subrepo, @main_repo
  config = Subrepo::Config.new(subrepo)
  expect(config.commit).to eq remote_repo.head.target.oid
  expect(config.parent).to eq repo.head.target.parents.last.oid
end

Then "the commit map should equal:" do |string|
  cd @main_repo do
    main = Subrepo::MainRepository.new
    sub = Subrepo::SubRepository.new(main, @subrepo)
    commit_map = Subrepo::CommitMapper.map_commits(sub)
    repo = main.repo
    named_map = commit_map.map do |from, to|
      [repo.lookup(from).summary, to && repo.lookup(to).summary]
    end
    width = named_map.map { _1.first.length }.max
    result = named_map.map do |from, to|
      "#{from.ljust(width)} -> #{to}"
    end
    expect(result.reverse.join("\n")).to eq string
  end
end

Then "I see that I need to resolve the conflict first" do
  expect(@error.to_s).to match(/Conflicts found/)
end

Then "I see that no existing merge commit is available" do
  expect(@error.to_s).to match(/No valid existing merge commit found/)
end

Then "the subrepo branch has been removed" do
  repo = Rugged::Repository.new expand_path(@main_repo)
  expect(repo.branches.map(&:name)).to eq ["master"]
end
