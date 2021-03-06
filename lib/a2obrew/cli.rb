# frozen_string_literal: true

require_relative 'git'
require_relative 'util'
require_relative 'cli_base'
require_relative 'libraries'
require_relative 'emscripten'
require_relative 'xcodebuild'

module A2OBrew
  class CLI < CLIBase
    desc 'commands', 'show all commands'
    def commands
      self.class.puts_commands
    end

    desc 'init [OPTIONS]', 'show shell script enables shims and autocompletion'
    def init(*args)
      print = false

      args.each do |arg|
        print = true if arg == '-'
      end

      if print
        shell = current_shell
        if %i[bash zsh].include?(shell)
          puts <<~COMPLETIONS
            source "#{a2obrew_path}/bin/completions/a2obrew.#{shell}"
          COMPLETIONS
        end
        puts <<~INIT
          source "#{emscripten_path}/emenv.sh"
        INIT
      else
        puts <<~USAGE
          # Load a2o related environment variables automatically by appending
          # the following to #{shell_rc_path}

          eval "$(a2obrew init -)"
        USAGE
      end
    end

    desc 'completions COMMAND', 'list completions for the COMMAND'
    def completions(*commands)
      return if commands.empty?

      case commands[0].intern
      when :libraries
        Libraries.completions(commands[1..-1])
      when :xcodebuild
        XcodeBuild.completions(commands[1..-1])
      when :emscripten
        Emscripten.completions(commands[1..-1])
      end
    end

    desc 'upgrade', 'upgrade whole system'
    method_option :target, aliases: '-t', default: 'release', desc: 'Build target (ex. release)'
    def upgrade
      target = options[:target]
      Emscripten.new.upgrade_main
      Libraries.new.upgrade_main([], target)
    end

    desc 'libraries SUBCOMMAND', 'handle libraries'
    subcommand 'libraries', Libraries

    desc 'xcodebuild SUBCOMMAND', 'build application with xcodeproj'
    subcommand 'xcodebuild', XcodeBuild

    desc 'emscripten SUBCOMMAND', 'handle emscripten'
    subcommand 'emscripten', Emscripten

    private

    def current_shell
      File.basename(ENV['SHELL']).intern if ENV.key?('SHELL')
    end

    def shell_rc_path
      case current_shell
      when :zsh
        '~/.zshrc'
      when :bash
        if File.exist?("#{ENV['HOME']}/.bashrc") && !File.exist?("#{ENV['HOME']}/.bash_profile")
          '~/.bashrc'
        else
          '~/.bash_profile'
        end
      else
        # cannot detect
        'your shell profile'
      end
    end
  end
end
