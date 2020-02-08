# frozen_string_literal: true

module Subrepo
  # SubRepository, represents a subrepo
  class SubRepository
    attr_reader :main_repository, :subdir

    def initialize(main_repository, subdir)
      @main_repository = main_repository
      @subdir = subdir
    end

    def map_commits(last_pushed_commit, last_merged_commit)
      Commands.map_commits(repo, subdir, last_pushed_commit,
                           last_merged_commit)
    end

    private

    def repo
      @repo ||= main_repository.repo
    end
  end
end
