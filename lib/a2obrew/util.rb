require 'mkmf'
require 'colorize'
require 'fileutils'

module MakeMakefile
  module Logging
    @logfile = File::NULL
  end
end

module A2OBrew
  class CmdExecException < StandardError
    attr_reader :exit_status

    def initialize(message, exit_status)
      @exit_status = exit_status
      super(message)
    end
  end

  class Informative < RuntimeError; end

  class Util
    def self.mkdir_p(path)
      FileUtils.mkdir_p(path) unless File.directory?(path)
    end

    def self.cmd_exec(cmd, error_msg = nil)
      puts_delimiter(cmd)
      pid = fork
      exec(cmd) if pid.nil?
      _, stat = Process.waitpid2(pid)
      if stat.exitstatus.nonzero?
        error_msg ||= "Error: #{cmd}"
        raise CmdExecException.new(error_msg, stat.exitstatus)
      end
      stat
    end

    def self.puts_delimiter(text)
      delimiter = ('=' * 78).colorize(color: :black, background: :white)
      puts delimiter
      puts text.colorize(color: :black, background: :white)
      puts delimiter
    end

    def self.error_exit(message, current_command, exit_status)
      puts(('*' * 78).colorize(color: :red))
      puts "a2obrew: #{message}".colorize(color: :red)
      puts(('*' * 78).colorize(color: :red))

      if current_command
        puts 'You can re-execute this phase with the command below.'
        puts current_command.colorize(color: :black, background: :white)
      end

      exit exit_status
    end
  end
end
