# frozen_string_literal: true

Given "I have an existing git project named {string}" do |proj|
  initialize_project proj
  @main_repo = proj
end

Given "I have committed a new file {string} in subdirectory {string}" do |file, subdir|
  subdir_with_commits_in_project(@main_repo, subdir: subdir, file: file)
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

When "I have updated and committed {string} in the remote" do |file|
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
  cd @main_repo do
    repo = Rugged::Repository.new(".")
    write_file "#{@subrepo}/#{file}", "new subrepo content"
    index = repo.index
    index.add "#{@subrepo}/#{file}"
    index.write
    Rugged::Commit.create(repo,
                          tree: index.write_tree,
                          message: "Update #{@subrepo}/#{file} in repo #{@main_repo}",
                          parents: [repo.head.target],
                          update_ref: "HEAD")
  end
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

When "I merge in the main project branch" do
  cd @main_repo do
    `git merge unrelated-branch`
  end
end

When "I commit a new file {string} in subdirectory {string}" do |file, subdir|
  subdir_with_commits_in_project(@main_repo, subdir: subdir, file: file)
end

When "I commit a new file {string} in the subrepo" do |file|
  subdir_with_commits_in_project(@main_repo, subdir: @subrepo, file: file)
end

When "I resolve the merge conflict with merged content" do
  expect(@error).not_to be_nil
  cd @main_repo do
    cd ".git/tmp/subrepo/#{@subrepo}" do
      status = `git status --porcelain`.chomp
      expect(status).to start_with "UU "
      file = status[3..-1]
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
      file = status[3..-1]
      `git checkout -q --ours #{file}`
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
    commit_map = sub.send :full_commit_map
    repo = main.repo
    named_map = commit_map.map do |from, to|
      [repo.lookup(from).summary, repo.lookup(to).summary]
    end
    width = named_map.map(&:first).map(&:length).max
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
