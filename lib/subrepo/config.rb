# frozen_string_literal: true

require "rugged"
require "subrepo/version"

module Subrepo
  class Config
    def initialize(subrepo)
      @subrepo = subrepo
    end

    attr_reader :subrepo

    def config_name
      @config_name ||= "#{subrepo}/.gitrepo"
    end

    def create(remote, branch)
      File.write(config_name, <<~HEADER)
        ; DO NOT EDIT (unless you know what you are doing)
        ;
        ; This subdirectory is a git "subrepo", and this file is maintained by the
        ; git-subrepo-ng command.
        ;
      HEADER

      config["subrepo.remote"] = remote.to_s
      config["subrepo.branch"] = branch.to_s
      config["subrepo.commit"] = ""
      config["subrepo.method"] = "merge"
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

    def parent
      config["subrepo.parent"]
    end

    private

    def config
      @config ||= Rugged::Config.new config_name
    end
  end
end
