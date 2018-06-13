# frozen_string_literal: true

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
    def check_emscripten_env
      error_exit(<<~SHOW_A2OBREW_INIT) if find_executable('emcc').nil?
        Cannot find emcc. Execute the command below.

        eval "$(a2obrew init -)"
      SHOW_A2OBREW_INIT
    end

    def a2obrew_path
      File.expand_path('../..', __dir__)
    end

    def emscripten_path
      "#{a2obrew_path}/emscripten"
    end

    def lang_path
      "#{a2obrew_path}/lang"
    end

    def emscripten_system_local_path
      "#{emscripten_path}/emscripten/system/local"
    end
  end
end
