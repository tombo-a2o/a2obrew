#!/usr/bin/env ruby
# encoding: utf-8

require 'thor'
require 'mkmf'
require 'colorize'
require 'fileutils'

module MakeMakefile
  module Logging
    @logfile = File::NULL
  end
end

require_relative 'xcode2ninja'

module A2OBrew
  class CLI < Thor # rubocop:disable Metrics/ClassLength
    def initialize(*args)
      super

      @current_command = "a2obrew #{ARGV.join(' ')}"
    end

    desc 'commands', 'show all commands of a2obrew'
    def commands
      self.class.commands.each do |command|
        puts command[0]
      end
    end

    desc 'init [OPTIONS]', 'show shell script enables shims and autocompletion'
    def init(*args)
      print = false

      args.each do |arg|
        print = true if arg == '-'
      end

      if print
        puts <<INIT
source "#{a2obrew_path}/bin/completions/a2obrew.#{current_shell}"
source "#{emsdk_path}/emsdk_env.sh"
INIT
      else
        puts <<USAGE
# Load emsdk_env automatically by appending
# the following to #{shell_rc_path}

eval "$(a2obrew init -)"
USAGE
      end
    end

    desc 'completions COMMAND', 'list completions for the COMMAND'
    def completions(*commands)
      return if commands.length == 0
      case commands[0].intern
      when :update, :autogen
        puts_build_completion(options, false)
      when :configure, :build, :install, :clean
        puts_build_completion(options, true)
        # TODO: xcodebuild
      end
    end

    desc 'update PROJECT_NAMES', 'update dependent repositories'
    def update(*proj_names)
      depends = A2OCONF[:depends]
      depends[:projects].each do |proj|
        @current_command = "a2obrew update #{proj[:name]}"

        next unless proj_names.length == 0 || proj_names.include?(proj[:name])
        proj_path = "#{depends[:path]}/#{proj[:path]}"
        git_update(proj_path, proj[:branch], proj[:repository_uri])
      end
    end

    desc 'autogen PROJECT_NAMES', 'autogen dependent repositories'
    def autogen(*proj_names)
      build_main(:autogen, proj_names)
    end

    desc 'configure PROJECT_NAMES', 'configure dependent repositories'
    method_option :target, aliases: '-t', default: 'release', desc: 'Build target (ex. release)'
    def configure(*proj_names)
      target = options[:target]
      build_main(:configure, proj_names, target)
    end

    desc 'build PROJECT_NAMES', 'build dependent repositories'
    method_option :target, aliases: '-t', default: 'release', desc: 'Build target (ex. release)'
    def build(*proj_names)
      target = options[:target]
      build_main(:build, proj_names, target)
    end

    desc 'install PROJECT_NAMES', 'install dependent repositories'
    method_option :target, aliases: '-t', default: 'release', desc: 'Build target (ex. release)'
    def install(*proj_names)
      target = options[:target]
      build_main(:install, proj_names, target)
    end

    desc 'clean PROJECT_NAMES', 'clean dependent repositories'
    method_option :target, aliases: '-t', default: 'release', desc: 'Build target (ex. release)'
    def clean(*proj_names)
      target = options[:target]
      build_main(:clean, proj_names, target)
    end

    PROJECT_CONFIG_RB_PATH = 'a2o_project_config.rb'
    desc 'xcodebuild', 'build application with config file'
    method_option :force, type: :boolean, aliases: '-f', default: false, desc: 'Force generate ninja.build and build'
    method_option :clean, type: :boolean, aliases: '-c', default: false, desc: 'Clean'
    method_option :project_config, aliases: '-p', desc: 'Project config ruby path'
    method_option :target, aliases: '-t', default: 'release', desc: 'Build target for a2o(ex. release)'
    def xcodebuild
      check_emsdk_env

      ninja_path = generate_ninja_build(options)
      ninja_command = generate_ninja_command(ninja_path, options[:clean])
      cmd_exec ninja_command, 'xcodebuild error'
    end

    private

    # TODO: Refactor to rubocop compliant
    def build_main(command, proj_names, target = nil) # rubocop:disable Metrics/MethodLength,Metrics/PerceivedComplexity,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/LineLength
      check_emsdk_env
      check_target(target)
      depends = A2OCONF[:depends]
      depends[:projects].each do |proj|
        @current_command = "a2obrew #{command} #{proj[:name]}"

        next unless proj_names.length == 0 || proj_names.include?(proj[:name]) || proj[command]

        proj_base_path = "#{depends[:path]}/#{proj[:path]}"

        if proj[:frameworks]
          proj_paths = proj[:frameworks].map { |framework| "#{proj_base_path}/#{framework}" }
        else
          proj_paths = [proj_base_path]
        end

        proj_paths.each do |proj_path|
          work_path = if command == :autogen
                        proj_path
                      else
                        build_path(proj_path, target, proj)
                      end
          build_target_path = build_target_path(proj_path, target, proj)

          unless command == :clean
            mkdir_p(work_path)
            mkdir_p(build_target_path)
          end

          cmd = proj[command] % {
            project_path: proj_path,
            build_target_path: build_target_path,
            emscripten_system_local_path: emscripten_system_local_path,
            cppflags: target ? A2OCONF[:targets][target.intern][:cppflags] : nil
          }

          cmd_exec "cd #{work_path} && #{cmd}", "Build Error: stop a2obrew #{command} #{proj[:name]}"
        end
      end
    end

    # die unless emcc
    def check_emsdk_env
      error_exit(<<EOF) if find_executable('emcc').nil?
Cannot find emcc. Execute the command below.

eval "$(a2obrew init -)"
EOF
    end

    # git pull if remote updated
    def git_update(root_path, branch_name, repository_uri) # rubocop:disable Metrics/MethodLength,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity,Metrics/LineLength
      git_path = "#{root_path}/.git"
      if File.directory?(root_path) && File.directory?(git_path)
        # git clone has already done

        git_command = "git --git-dir=#{git_path} --work-tree=#{root_path}"

        # Change current branch if needed
        current_branch = `#{git_command} rev-parse --abbrev-ref HEAD`

        if branch_name && current_branch != branch_name
          cmd_exec "#{git_command} checkout #{branch_name}", "fail to change the branch from #{current_branch} to #{branch_name}" # rubocop:disable Metrics/LineLength
        end

        # check the repository is up to date or not
        cmd_exec "#{git_command} remote update", 'fail to git remote update'
        local = `#{git_command} rev-parse @`
        remote = `#{git_command} rev-parse @{u}`
        base = `#{git_command} merge-base @ @{u}`

        if local == remote
          puts "#{root_path} is up to date."
        elsif local == base
          # git pull if needed
          cmd_exec "#{git_command} pull", "git pull fails on #{root_path}"
        elsif remote == base
          error_exit "You must do 'git push' on #{root_path}"
        else
          # diverged
          error_exit "You must update #{root_path} yourself"
        end
      else
        # git clone hasn't done yet, so do git clone
        if branch_name
          branch_option = "--branch #{branch_name}"
        else
          branch_option = ''
        end
        cmd_exec "git clone #{repository_uri} #{branch_option} #{root_path}", "git clone fails from #{repository_uri} with the branch #{branch_name} to #{root_path}" # rubocop:disable Metrics/LineLength
      end
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

    def check_target(target)
      error_exit(<<EOF) unless target.nil? || A2OCONF[:targets].key?(target.intern)
Invalid target '#{target}'.
You must specify #{A2OCONF[:targets].keys.join('/')}.
EOF
    end

    def current_shell
      File.basename(ENV['SHELL']).intern
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

    def build_path(project_path, target, project_conf)
      if project_conf[:build_path]
        project_conf[:build_path] % {
          project_path: project_path,
          target: target
        }
      else
        "#{project_path}/build/#{target}"
      end
    end

    def build_target_path(project_path, target, project_conf)
      if project_conf[:build_target_path]
        project_conf[:build_target_path] % {
          project_path: project_path,
          target: target
        }
      else
        "#{project_path}/build/#{target}"
      end
    end

    def error_exit(message, exit_status = 1)
      puts(('*' * 78).colorize(color: :red))
      puts "a2obrew: #{message}".colorize(color: :red)
      puts(('*' * 78).colorize(color: :red))

      if @current_command
        puts 'You can re-execute this phase with the command below.'
        puts @current_command.colorize(color: :black, background: :white)
      end

      exit exit_status
    end

    def project_names
      A2OCONF[:depends][:projects].map { |proj| proj[:name] }
    end

    def puts_build_completion(options, with_target = true)
      return unless options[:complete]

      if with_target
        A2OCONF[:targets].each do |target|
          puts "--target=#{target}"
        end
      end
      puts project_names.join("\n")
      exit(0)
    end

    def mkdir_p(path)
      FileUtils.mkdir_p(path) unless File.directory?(path)
    end

    def cmd_exec(cmd, error_msg = nil)
      puts_delimiter(cmd)
      pid = fork
      exec(cmd) if pid.nil?
      _, stat = Process.waitpid2(pid)
      if stat.exitstatus != 0
        error_msg ||= "Error: #{cmd}"
        error_exit error_msg, stat.exitstatus
      end
      stat
    end

    def puts_delimiter(text)
      delimiter = ('=' * 78).colorize(color: :black, background: :white)
      puts delimiter
      puts text.colorize(color: :black, background: :white)
      puts delimiter
    end

    def read_project_config(path)
      if File.exist?(path)
        config = eval File.read(path) # rubocop:disable Lint/Eval
        unless config[:version] == 1
          fail Informative, '#{BUILD_CONFIG_RB_PATH} version should be 1'
        end
        config
      else
        {}
      end
    end

    def load_project_config(project_config_path)
      unless project_config_path.nil? || File.exist?(project_config_path)
        error_exit "Specified #{project_config_path} not found"
      end

      project_config_path ||= PROJECT_CONFIG_RB_PATH

      if File.exist?(project_config_path)
        proj_config = read_project_config(project_config_path)
      else
        proj_config = {}
      end

      proj_config
    end

    def search_xcodeproj_path(xcodeproj_path)
      if xcodeproj_path.nil?
        projects = Dir.glob('*.xcodeproj')
        if projects.size == 1
          xcodeproj_path = projects.first
        elsif projects.size > 1
          error_exit('There are more than one Xcode projects. Use project config.')
        else
          error_exit('No Xcode project in the current working directory.')
        end
      end

      unless FileTest.directory?(xcodeproj_path)
        error_exit('Specify valid .xcodeproj path')
      end

      xcodeproj_path
    end

    def find_xcodeproj_build_config(active_project_config)
      xcodeproj_build_config = active_project_config[:xcodeproj_build_config]
      unless xcodeproj_build_config # rubocop:disable Style/GuardClause
        xcodeproj_build_config = {
          debug: 'Debug',
          release: 'Release'
        }[a2o_target]

        error_exit('Cannot determine xcodeproj_build_config') unless xcodeproj_build_config
      end

      xcodeproj_build_config
    end

    def generate_ninja_build(options) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      a2o_target = options[:target].intern
      proj_config = load_project_config(options[:project_config])
      xcodeproj_path = search_xcodeproj_path(options[:xcodeproj_path])
      xcodeproj_target = proj_config[:xcodeproj_target] || File.basename(xcodeproj_path, '.xcodeproj')
      active_project_config = fetch_active_project_config(proj_config, a2o_target)
      xcodeproj_build_config = find_xcodeproj_build_config(active_project_config)
      ninja_path = "ninja/#{a2o_target}.ninja.build"

      if options[:force] || !File.exist?(ninja_path) || (File.mtime(xcodeproj_path) > File.mtime(ninja_path))
        puts_delimiter("# Generate #{ninja_path}")
        puts <<EOF
a2o:
  target: #{a2o_target}
xcodeproj:
  xcodeproj_path: #{xcodeproj_path}
  xcodeproj_target: #{xcodeproj_target}
  xocdeproj_build_config: #{xcodeproj_build_config}
EOF
        xn = Xcode2Ninja.new(xcodeproj_path)
        gen_paths = xn.xcode2ninja('ninja', xcodeproj_target, xcodeproj_build_config, active_project_config, a2o_target)
        gen_paths.each do |path|
          puts "Generate #{path}"
        end
      end

      ninja_path
    end

    def fetch_active_project_config(proj_config, a2o_target)
      begin
        active_project_config = proj_config[:a2o_targets][a2o_target]
      rescue
        active_project_config = {}
      end
      active_project_config
    end

    def generate_ninja_command(ninja_path, clean)
      if clean
        "ninja -v -f #{ninja_path} -t clean"
      else
        "ninja -v -f #{ninja_path}"
      end
    end
  end
end
