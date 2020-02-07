# frozen_string_literal: true

Given("I have an existing git project named {string}") do |proj|
  initialize_project proj
  @main_repo = proj
end

Given("I have a subdirectory {string} with commits") do |subdir|
  subdir_with_commits_in_project(@main_repo, subdir: subdir)
end

Given("I have an empty remote named {string}") do |remote|
  empty_remote(remote)
  @remote = remote
end

Given "I have a git project {string} with subrepo {string} with remote {string}" \
  do |proj, subdir, remote|
  initialize_project proj
  subdir_with_commits_in_project(proj, subdir: subdir)
  empty_remote(remote)
  @main_repo = proj
  @subrepo = subdir
  @remote = remote
end

Given("I have a git project with a subrepo with a remote") do
  @main_repo = "foo"
  @subrepo = "bar"
  @remote = "baz"
  initialize_project @main_repo
  subdir_with_commits_in_project(@main_repo, subdir: @subrepo)
  empty_remote(@remote)
end

Given "I have a remote named {string} with some commits" do |remote|
  empty_remote(remote)
  @remote = remote
  full_remote = expand_path @remote
  remote_commit_add(full_remote, "this_file", "stuff")
  remote_commit_add(full_remote, "other_file", "more stuff")
end

When("I add a new commit to the subrepo") do
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

When("I add a new commit to the remote") do
  repo = Rugged::Repository.new expand_path(@remote)
  index = repo.index
  index.read_tree(repo.head.target.tree)
  new_blob_oid = repo.write("new content", :blob)
  index.add path: "another_file", oid: new_blob_oid, mode: 0o100644
  Rugged::Commit.create(repo, tree: index.write_tree,
                        message: "Add another_file in remote #{@remote}",
                        parents: [repo.head.target], update_ref: "HEAD")
end

When("I create a branch with some commits in the main project") do
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

When("I merge in the main project branch") do
  cd @main_repo do
    `git merge unrelated-branch`
  end
end

Then("the subrepo and the remote should have the same contents") do
  repo = Rugged::Repository.new expand_path(@remote)
  tree = repo.head.target.tree
  subrepo = expand_path @subrepo, @main_repo
  expected_entries = Dir.new(subrepo).entries - %w(. .. .gitrepo)
  subrepo_entries = tree.entries.map { |it| it[:name] }
  expect(subrepo_entries).to match_array expected_entries
  tree.entries.each do |entry|
    raise "Unsupported" unless entry[:type] == :blob

    blob = repo.lookup entry[:oid]
    expect(blob.text).to eq File.read(File.join(subrepo, entry[:name]))
  end
end

Then("the remote's log should equal:") do |string|
  log = get_log_from_repo(@remote)
  expect(log).to eq string
end

Then("the project's log should equal:") do |string|
  log = get_log_from_repo(@main_repo)
  expect(log).to eq string
end

Then("the subrepo configuration should contain the latest commit and parent") do
  remote_repo = Rugged::Repository.new expand_path(@remote)
  repo = Rugged::Repository.new expand_path(@main_repo)
  subrepo = expand_path @subrepo, @main_repo
  config = Subrepo::Config.new(subrepo)
  expect(config.commit).to eq remote_repo.head.target.oid
  expect(config.parent).to eq repo.head.target.parents.last.oid
end
