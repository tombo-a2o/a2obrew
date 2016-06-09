#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'cli_base'
require_relative 'applications'
require_relative 'application_versions'

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
  end
end
