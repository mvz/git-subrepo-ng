# frozen_string_literal: true

Given("I have initialized and pushed the subrepo") do
  cd(@main_repo) do
    Subrepo::Commands.command_init @subrepo, remote: "../#{@remote}", branch: "master"
    Subrepo::Commands.command_push @subrepo
  end
end

When "I init the subrepo {string} with remote {string} and branch {string}" \
  do |subrepo, remote, branch|
  cd(@main_repo) do
    @subrepo = subrepo
    Subrepo::Commands.command_init @subrepo, remote: remote, branch: branch
  end
end

When("I push the subrepo {string}") do |subrepo|
  cd(@main_repo) do
    Subrepo::Commands.command_push subrepo
  end
end

When("I pull the subrepo with squashing( again)") do
  cd(@main_repo) do
    Subrepo::Commands.command_pull @subrepo, squash: true
  end
end

When("I pull the subrepo without squashing( again)") do
  cd(@main_repo) do
    Subrepo::Commands.command_pull @subrepo, squash: false
  end
end

When "I clone into {string} from the remote {string} with branch {string}" \
  do |subdir, remote, branch|
  cd(@main_repo) do
    @subrepo = subdir
    Subrepo::Commands.command_clone remote, @subrepo, branch: branch
  end
end
