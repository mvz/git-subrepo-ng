When("I init the subrepo {string} with remote {string} and branch {string}") do |subrepo, remote, branch|
  cd(@main_repo) do
    run_command_and_stop "git-subrepo init #{subrepo} --remote #{remote} --branch #{branch}"
  end
end
