# frozen_string_literal: true

require "open3"

module Subrepo
  # Entry point for each of the subrepo commands
  module Commands
    module_function

    def run_command(command)
      _out, _err, status = Open3.capture3 command
      status == 0 or raise "Command failed"
    end
  end
end
