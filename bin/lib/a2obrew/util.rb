module A2OBrew
  class CmdExecException < StandardError
    attr_reader :exit_status

    def initialize(msg, exit_status)
      @exit_status = exit_status
      super(msg)
    end
  end

  class Util
    def self.mkdir_p(path)
      FileUtils.mkdir_p(path) unless File.directory?(path)
    end

    def self.cmd_exec(cmd, error_msg = nil)
      puts_delimiter(cmd)
      pid = fork
      exec(cmd) if pid.nil?
      _, stat = Process.waitpid2(pid)
      if stat.exitstatus != 0
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
  end
end
