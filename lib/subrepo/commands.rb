# frozen_string_literal: true

require "open3"

module Subrepo
  # Provides interface to running external commands
  module Commands
    module_function

    def run_command(command)
      out, err, status = Open3.capture3 command
      if status != 0
        message = "Command failed: '#{command}'."
        message += "\nreason: #{err}" if $DEBUG
        raise message
      end
      out
    end
  end
end
