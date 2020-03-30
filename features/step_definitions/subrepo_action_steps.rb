# frozen_string_literal: true

Given "I have initialized the subrepo {string} with that remote" do |subrepo|
  cd @main_repo do
    @subrepo = subrepo
    Subrepo::Runner.new.run_init @subrepo, remote: "../#{@remote}", branch: "master"
  end
end

When "I init the subrepo {string} with remote {string} and branch {string}" \
  do |subrepo, remote, branch|
  cd @main_repo do
    @subrepo = subrepo
    Subrepo::Runner.new.run_init @subrepo, remote: remote, branch: branch
  end
end

When "I (have )push(ed) the subrepo {string}( again)" do |subrepo|
  cd @main_repo do
    Subrepo::Runner.new.run_push subrepo, squash: false
  end
end

When "I (have )push(ed) the subrepo {string}( again), squashing the commits" do |subrepo|
  cd @main_repo do
    Subrepo::Runner.new.run_push subrepo, squash: true
  end
end

When "I push the subrepo" do
  cd @main_repo do
    Subrepo::Runner.new.run_push @subrepo, squash: false
  end
end

When "I pull the subrepo with squashing( again)" do
  cd @main_repo do
    Subrepo::Runner.new.run_pull @subrepo, squash: true
  end
end

When "I pull the subrepo without squashing( again)" do
  cd @main_repo do
    Subrepo::Runner.new.run_pull @subrepo, squash: false
  end
end

When "I attempt to pull the subrepo" do
  @error = nil
  cd @main_repo do
    Subrepo::Runner.new.run_pull @subrepo, squash: false
  end
rescue StandardError => e
  @error = e.message
end

When "I fetch new commits for the subrepo from the remote" do
  cd @main_repo do
    Subrepo::Runner.new.run_fetch @subrepo
  end
end

When "I clone into {string} from the remote {string} with branch {string}" \
  do |subdir, remote, branch|
  cd @main_repo do
    @subrepo = subdir
    Subrepo::Runner.new.run_clone remote, @subrepo, branch: branch
  end
end

When "I finalize the pull using the subrepo commit subcommand" do
  cd @main_repo do
    Subrepo::Runner.new.run_commit @subrepo, squash: false, message: nil, edit: false
  end
end

When "I attempt to commit( without resolving the conflict)" do
  @error = nil
  cd @main_repo do
    Subrepo::Runner.new.run_commit @subrepo, squash: false, message: nil, edit: false
  end
rescue StandardError => e
  @error = e.message
end
