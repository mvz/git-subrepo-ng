# frozen_string_literal: true

module Subrepo
  # Stand-in for STDOUT that does nothing
  class NullOutput
    def puts(*args); end
  end
end
