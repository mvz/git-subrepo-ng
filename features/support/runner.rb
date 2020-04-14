# frozen_string_literal: true

require "rugged"

# Helper method to run subrepo commands
module Runner
  def run_subrepo_command(cmd, *args, **options)
    flags = options.flat_map do |name, value|
      case value
      when true
        "--#{name}"
      when false
        "--no-#{name}"
      else
        ["--#{name}", value.to_s]
      end
    end
    arguments = [cmd, *args, *flags]
    cli_output.rewind
    runner.run arguments
  end

  def runner
    @runner ||= Subrepo::CLI.new(output: cli_output).tap do |cli|
      cli.setup
      cli.on_error { |ex| raise ex }
    end
  end

  def cli_output
    @cli_output ||= StringIO.new
  end
end

World Runner
