# frozen_string_literal: true

When "I (have )initialize(d) the subrepo {string} with the/that remote" do |subrepo|
  cd @main_repo do
    @subrepo = subrepo
    run_subrepo_command :init, @subrepo, remote: "../#{@remote}", branch: "master"
  end
end

When "I init the subrepo {string} with remote {string} and branch {string}" \
  do |subrepo, remote, branch|
  cd @main_repo do
    @subrepo = subrepo
    run_subrepo_command :init, @subrepo, remote: remote, branch: branch
  end
end

When "I (have )push(ed) the subrepo {string}( again)" do |subrepo|
  cd @main_repo do
    run_subrepo_command :push, subrepo
  end
end

When "I (have )push(ed) the subrepo {string}( again), squashing the commits" do |subrepo|
  cd @main_repo do
    run_subrepo_command :push, subrepo, squash: true
  end
end

When "I push the subrepo" do
  cd @main_repo do
    run_subrepo_command :push, @subrepo, squash: false
  end
end

When "I get the status of the subrepo {string}" do |subrepo|
  cd @main_repo do
    run_subrepo_command :status, subrepo
  end
end

When "I get the status of all subrepos recursively" do
  cd @main_repo do
    run_subrepo_command :status, all_recursive: true
  end
end

When "I get the status of all subrepos" do
  cd @main_repo do
    run_subrepo_command :status, all: true
  end
end

When "I pull the subrepo( again)" do
  cd @main_repo do
    run_subrepo_command :pull, @subrepo
  end
end

When "I pull the subrepo with squashing( again)" do
  cd @main_repo do
    run_subrepo_command :pull, @subrepo, squash: true
  end
end

When "I pull all subrepos" do
  cd @main_repo do
    run_subrepo_command :pull, all: true
  end
end

When "I attempt to pull the subrepo" do
  @error = nil
  cd @main_repo do
    run_subrepo_command :pull, @subrepo
  end
rescue StandardError => e
  @error = e.message
end

When "I fetch new commits for the subrepo from the remote" do
  cd @main_repo do
    run_subrepo_command :fetch, @subrepo
  end
end

When "I (have )clone(d) into {string} from the remote {string} with branch {string}" \
  do |subdir, remote, branch|
  cd @main_repo do
    @subrepo = subdir
    run_subrepo_command :clone, remote, @subrepo, branch: branch
  end
end

When "I finalize the pull using the subrepo commit subcommand" do
  cd @main_repo do
    run_subrepo_command :commit, @subrepo
  end
end

When "I attempt to commit( without resolving the conflict)" do
  @error = nil
  cd @main_repo do
    run_subrepo_command :commit, @subrepo
  end
rescue StandardError => e
  @error = e.message
end

When "I create a subrepo branch and worktree" do
  cd @main_repo do
    run_subrepo_command :branch, @subrepo
  end
end

When "I clean the subrepo" do
  cd @main_repo do
    run_subrepo_command :clean, @subrepo
  end
end

Then "the subrepo command output should match:" do |string|
  expect(cli_output.string).to match string
end
