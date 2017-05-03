# frozen_string_literal: true
require 'pty'
require 'mkmf'
require 'rainbow'
require 'RMagick'
require 'fileutils'

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

    def self.cmd_exec(cmd, error_msg = nil, &output_filter)
      puts_delimiter(cmd)
      PTY.spawn(cmd) do |stdout, stdin, pid|
        begin
          stdin.close
          stdout.each do |line|
            if output_filter.nil?
              puts line
            else
              yield line
            end
          end
        rescue Errno::EIO # rubocop:disable Lint/HandleExceptions
        rescue Interrupt
          raise CmdExecException.new('Interrupt', 1)
        end
        Process.wait pid
      end
      stat = $CHILD_STATUS
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
        puts Rainbow(current_command).color(:black).background(:white)
      end

      exit exit_status
    end

    def self.image_width_and_height(path)
      img = Magick::ImageList.new(path)
      [img.columns, img.rows]
    end

    def self.filter_ansi_esc(str)
      str.gsub(/\e\[\d{1,3}[mK]/, '')
    end
  end
end
