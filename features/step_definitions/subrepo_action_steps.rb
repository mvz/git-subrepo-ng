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
    Subrepo::Commands.command_init subrepo, remote: remote, branch: branch
  end
end

When("I push the subrepo {string}") do |subrepo|
  cd(@main_repo) do
    Subrepo::Commands.command_push subrepo
  end
end
