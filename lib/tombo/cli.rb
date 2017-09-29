# frozen_string_literal: true

require_relative 'cli_base'
require_relative 'applications'
require_relative 'application_versions'
require_relative 'application_localizes'
require_relative 'developers'
require_relative 'test'
require_relative 'gp_applications'
require_relative 'gp_application_versions'

module Tombo
  class CLI < CLIBase
    desc 'commands', 'show all commands'
    def commands
      self.class.puts_commands
    end

    desc 'applications SUBCOMMAND', 'handle applications'
    subcommand 'applications', Applications

    desc 'application_versions SUBCOMMAND', 'handle application versions'
    subcommand 'application_versions', ApplicationVersions

    desc 'application_localizes SUBCOMMAND', 'handle application localizes'
    subcommand 'application_localizes', ApplicationLocalizes

    desc 'developers SUBCOMMAND', 'handle developers'
    subcommand 'developers', Developers

    desc 'test SUBCOMMAND', 'test with local Tombo platform'
    subcommand 'test', Test

    desc 'gp_applications SUBCOMMAND', 'handle gameplus applications'
    subcommand 'gp_applications', GpApplications

    desc 'gp_application_versions SUBCOMMAND', 'handle gameplus application versions'
    subcommand 'gp_application_versions', GpApplicationVersions
  end
end
