# frozen_string_literal: true

require "rugged"

module Subrepo
  # Main repository, possibly containing subrepo's
  class MainRepository
    attr_reader :repo

    def initialize
      @repo = Rugged::Repository.new(".")
    end

    def subrepos(recursive: false)
      tree = repo.head.target.tree
      subrepos = []
      tree.walk_blobs do |path, blob|
        next if blob[:name] != ".gitrepo"

        unless recursive
          next if subrepos.any? { |it| path.start_with? it }
        end
        subrepos << path
      end
      subrepos.map(&:chop)
    end
  end
end
