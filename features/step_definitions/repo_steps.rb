Given("I have an existing git project named {string}") do |proj|
  create_directory proj
  cd proj do
    repo = Rugged::Repository.init_at(".")
    write_file "README", "Hi!"
    index = repo.index
    index.add "README"
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
    Rugged::Commit.create(repo, tree: index.write_tree, message: "Add stuff in #{subdir}",
                          parents: [repo.head.target], update_ref: "HEAD")
  end
end

Given("I have an empty remote named {string}") do |remote|
  in_current_directory do
    Rugged::Repository.init_at(remote, :bare)
  end
end
