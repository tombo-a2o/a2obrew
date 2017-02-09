# frozen_string_literal: true
require 'mkmf'
require 'rainbow'
require 'fileutils'

# Force enable for Rainbow even if the STDOUT/STDERR aren't terminals
Rainbow.enabled = true

module MakeMakefile
  module Logging
    @logfile = File::NULL
  end
end

class String
  def to_camel
    split('_').each_with_index.map do |w, i|
      w[0] = w[0].upcase if i.positive?
      w
    end.join
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
      delimiter = Rainbow('=' * 78).color(:black).background(:white)
      puts delimiter
      puts Rainbow(text).color(:black).background(:white)
      puts delimiter
    end

    def self.error_exit(message, current_command, exit_status)
      puts Rainbow('*' * 78).color(:red)
      puts Rainbow("a2obrew: #{message}").color(:red)
      puts Rainbow('*' * 78).color(:red)

      if current_command
        puts 'You can re-execute this phase with the command below.'
        puts current_command.color(:black).background(:white)
      end

      exit exit_status
    end
  end
end
