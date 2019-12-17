# frozen_string_literal: true

Given("I have an existing git project named {string}") do |proj|
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
  @main_repo = proj
end

Given("I have a subdirectory {string} with commits") do |subdir|
  cd @main_repo do
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

Given("I have an empty remote named {string}") do |remote|
  in_current_directory do
    Rugged::Repository.init_at(remote, :bare)
  end
  @remote = remote
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
