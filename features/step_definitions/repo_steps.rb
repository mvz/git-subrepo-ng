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

When("I add a new commit to the subrepo") do
  cd @main_repo do
    repo = Rugged::Repository.new(".")
    write_file "#{@subrepo}/other_file", "more stuff"

    index = repo.index
    index.add_all
    index.write
    Rugged::Commit.create(repo, tree: index.write_tree,
                          message: "Add more stuff in #{@subrepo}",
                          parents: [repo.head.target], update_ref: "HEAD")
  end
end

Then("the remote should contain the contents of {string}") do |string|
  repo = Rugged::Repository.new expand_path(@remote)
  tree = repo.head.target.tree
  subrepo = expand_path string, @main_repo
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
  repo = Rugged::Repository.new expand_path(@remote)
  walker = Rugged::Walker.new(repo)
  walker.push repo.head.target.oid
  log = walker.map(&:summary).join("\n")
  expect(log).to eq string
end
