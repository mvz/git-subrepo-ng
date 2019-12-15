Given("I have an existing git project named {string}") do |proj|
  create_directory proj
  cd proj do
    system "git init"
    write_file "README", "Hi!"
    system "git add -A"
    system "git commit -am 'Initial commit'"
  end
  @main_repo = proj
end

Given("I have a subdirectory {string} with commits") do |subdir|
  cd @main_repo do
    create_directory subdir
    write_file "#{subdir}/a_file", "stuff"
    system "git add -A"
    system "git commit -am 'Add stuff in #{subdir}'"
  end
end

Given("I have an empty remote named {string}") do |remote|
  in_current_directory do
    system "git init --bare #{remote}"
  end
end
