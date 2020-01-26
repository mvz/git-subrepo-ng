# frozen_string_literal: true

require "rugged"
require "subrepo/version"

module Subrepo
  # Encapsulate operations on the subrepo config stored in .gitrepo
  class Config
    def initialize(subrepo)
      @subrepo = subrepo
    end

    attr_reader :subrepo

    def file_name
      @file_name ||= File.join(subrepo, ".gitrepo")
    end

    def create(remote, branch, method)
      File.write(file_name, <<~HEADER)
        ; DO NOT EDIT (unless you know what you are doing)
        ;
        ; This subdirectory is a git "subrepo", and this file is maintained by the
        ; git-subrepo-ng command.
        ;
      HEADER

      config["subrepo.remote"] = remote.to_s
      config["subrepo.branch"] = branch.to_s
      config["subrepo.commit"] = ""
      config["subrepo.method"] = method.to_s
      config["subrepo.cmdver"] = Subrepo::VERSION
    end

    def remote
      config["subrepo.remote"]
    end

    def branch
      config["subrepo.branch"]
    end

    def commit
      config["subrepo.commit"]
    end

    def commit=(commit_sha)
      config["subrepo.commit"] = commit_sha
    end

    def parent
      config["subrepo.parent"]
    end

    def parent=(parent_sha)
      config["subrepo.parent"] = parent_sha
    end

    private

    def config
      @config ||= Rugged::Config.new file_name
    end
  end
end
