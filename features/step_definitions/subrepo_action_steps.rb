When("I init the subrepo {string} with remote {string} and branch {string}") do |subrepo, remote, branch|
  cd(@main_repo) do
    Subrepo::Commands.command_init subrepo, remote: remote, branch: branch
  end
end
