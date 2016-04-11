require 'thor'
require_relative 'util'

module A2OBrew
  class CLIBase < Thor
    def initialize(*args)
      super

      @current_command = "a2obrew #{ARGV.join(' ')}"
    end

    def self.puts_commands
      commands.each do |command|
        puts command[0]
      end
      exit(0)
    end

    private

    def error_exit(message, exit_status = 1)
      Util.error_exit(message, @current_command, exit_status)
    end

    # die unless emcc
    def check_emsdk_env
      error_exit(<<EOF) if find_executable('emcc').nil?
Cannot find emcc. Execute the command below.

eval "$(a2obrew init -)"
EOF
    end

    def a2obrew_path
      File.expand_path('../../../..', __FILE__)
    end

    def emsdk_path
      "#{a2obrew_path}/emsdk"
    end

    def emscripten_system_local_path
      # FIXME: use $EMSCRIPTEN
      "#{emsdk_path}/emscripten/a2o/system/local"
    end
  end
end
