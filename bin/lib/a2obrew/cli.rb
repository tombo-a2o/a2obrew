#!/usr/bin/env ruby
# encoding: utf-8

require 'thor'
require 'mkmf'; module MakeMakefile::Logging; @logfile = File::NULL; end
require 'colorize'
require 'fileutils'

require_relative 'xcode2ninja'

module A2OBrew
  class CLI < Thor
    desc 'commands', 'show all commands of a2obrew'
    def commands
      self.class.commands.each {|command|
        puts command[0]
      }
    end

    desc 'init [OPTIONS]', 'show shell script enables shims and autocompletion'
    def init(*args)
      print = false

      args.each {|arg|
        if arg == '-'
          print = true
        end
      }

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
    def completions(command)
      case command.intern
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
      depends[:projects].each {|proj|
        unless proj_names.length == 0 or proj_names.include?(proj[:name])
          next
        end
        proj_path = "#{depends[:path]}/#{proj[:path]}"
        git_update(proj_path, proj[:branch], proj[:repository_uri])
      }
    end

    desc 'autogen PROJECT_NAMES', 'autogen dependent repositories'
    def autogen(*proj_names)
      build_main(:autogen, proj_names)
    end

    desc 'configure PROJECT_NAMES', 'configure dependent repositories'
    method_option :target, :aliases => '-t', :default => 'release', :desc => 'Build target (ex. release)'
    def configure(*proj_names)
      target = options[:target]
      build_main(:configure, proj_names, target)
    end

    desc 'build PROJECT_NAMES', 'build dependent repositories'
    method_option :target, :aliases => '-t', :default => 'release', :desc => 'Build target (ex. release)'
    def build(*proj_names)
      target = options[:target]
      build_main(:build, proj_names, target)
    end

    desc 'install PROJECT_NAMES', 'install dependent repositories'
    method_option :target, :aliases => '-t', :default => 'release', :desc => 'Build target (ex. release)'
    def install(*proj_names)
      target = options[:target]
      build_main(:install, proj_names, target)
    end

    desc 'clean PROJECT_NAMES', 'clean dependent repositories'
    method_option :target, :aliases => '-t', :default => 'release', :desc => 'Build target (ex. release)'
    def clean(*proj_names)
      target = options[:target]
      build_main(:clean, proj_names, target)
    end

    desc 'xcodebuild XCODEPROJ', 'build application'
    method_option :force, :type => :boolean, :aliases => '-f', :default => false, :desc => 'Force generate ninja.build and build'
    method_option :clean, :type => :boolean, :aliases => '-c', :default => false, :desc => 'Clean'
    method_option :build_configuration, :aliases => '-b', :default => 'Release', :desc => 'Build configration (ex. Release)'
    def xcodebuild(proj_path = nil)
      check_emsdk_env

      # find xcoreproj directory
      if proj_path.nil?
        projects = Dir.glob('*.xcodeproj')
        if projects.size == 1
          proj_path = projects.first
        elsif projects.size > 1
          error_exit('There are more than one Xcode projects in the current working directory. Specify project path expressly.')
        else
          error_exit('No Xcode project in the current working directory.')
        end
      end

      unless FileTest.directory?(proj_path)
        error_exit('Specify valid .xcodeproj path')
      end

      # TODO: add option for target_name
      target_name = File.basename(proj_path, '.xcodeproj')
      bc = options[:build_configuration]

      ninja_path = "ninja/#{target_name}.#{bc}.ninja.build"

      # generate ninja.build
      if options[:force] or not File.exists?(ninja_path) or File.mtime(proj_path) > File.mtime(ninja_path)
        puts_delimiter("# Generate #{ninja_path}")
        xn = Xcode2Ninja.new(proj_path)
        puts "target: #{target_name} build_configration: #{bc}"
        gen_paths = xn.xcode2ninja('ninja', target_name, bc)
        gen_paths.each do |path|
          puts "Generate #{path}"
        end
      end

      # execute ninja
      if options[:clean]
        cmd_exec "ninja -v -f #{ninja_path} -t clean"
      else
        cmd_exec "ninja -v -f #{ninja_path}"
      end
    end

    private

    def build_main(command, proj_names, target=nil)
      check_emsdk_env
      check_target(target)
      depends = A2OCONF[:depends]
      depends[:projects].each {|proj|
        unless proj_names.length == 0 or proj_names.include?(proj[:name])
          next
        end

        if proj[command]
          proj_base_path = "#{depends[:path]}/#{proj[:path]}"

          if proj[:frameworks]
            proj_paths = proj[:frameworks].map {|framework| "#{proj_base_path}/#{framework}"}
          else
            proj_paths = [proj_base_path]
          end

          proj_paths.each {|proj_path|
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
              :project_path => proj_path,
              :build_target_path => build_target_path,
              :emscripten_system_local_path => emscripten_system_local_path,
              :cppflags => target ? A2OCONF[:targets][target.intern][:cppflags] : nil,
            }

            cmd_exec "cd #{work_path} && #{cmd}"
          }
        end
      }
    end

    # die unless emcc
    def check_emsdk_env
      if find_executable('emcc').nil?
        error_exit("Cannot find emcc. Execute the command below.\n\neval \"$(a2obrew init -)\"")
      end
    end

    # git pull if remote updated
    def git_update(root_path, branch_name, repository_uri)
      git_path = "#{root_path}/.git"
      if File.directory?(root_path) and File.directory?(git_path)
        # git clone has already done

        git_command = "git --git-dir=#{git_path} --work-tree=#{root_path}"

        # Change current branch if needed
        current_branch = `#{git_command} rev-parse --abbrev-ref HEAD`

        if branch_name and current_branch != branch_name
          cmd_exec "#{git_command} checkout #{branch_name}"
        end

        # check the repository is up to date or not
        cmd_exec "#{git_command} remote update"
        local = `#{git_command} rev-parse @`
        remote = `#{git_command} rev-parse @{u}`
        base = `#{git_command} merge-base @ @{u}`

        if local == remote
          puts "#{root_path} is up to date."
        elsif local == base
          # git pull if needed
          stat = cmd_exec "#{git_command} pull"
          if stat.exitstatus != 0
            error_exit "git pull fails on #{root_path}"
          end
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
        cmd_exec "git clone #{repository_uri} #{branch_option} #{root_path}"
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
      unless target.nil? or A2OCONF[:targets].has_key?(target.intern)
        error_exit("Invalid target '#{target}'. You must specify #{A2OCONF[:targets].keys.join('/')}.")
      end
    end

    def current_shell
      File.basename(ENV['SHELL']).intern
    end

    def shell_rc_path
      case current_shell
      when :zsh
        '~/.zshrc'
      when :bash
        if File.exists?("#{ENV['HOME']}/.bashrc") and not File.exists?("#{ENV['HOME']}/.bash_profile")
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
          :project_path => project_path,
          :target => target,
        }
      else
        "#{project_path}/build/#{target}"
      end
    end

    def build_target_path(project_path, target, project_conf)
      if project_conf[:build_target_path]
        project_conf[:build_target_path] % {
          :project_path => project_path,
          :target => target,
        }
      else
        "#{project_path}/build/#{target}"
      end
    end

    def error_exit(message)
      puts "a2obrew: #{message}"
      exit(1)
    end

    def project_names
      A2OCONF[:depends][:projects].map {|proj| proj[:name] }
    end

    def puts_build_completion(options, with_target=true)
      return unless options[:complete]

      if with_target
        A2OCONF[:targets].each {|target|
          puts "--target=#{target}"
        }
      end
      puts project_names.join("\n")
      exit(0)
    end

    def mkdir_p(path)
      unless File.directory?(path)
        FileUtils.mkdir_p(path)
      end
    end

    def cmd_exec(cmd)
      puts_delimiter(cmd)
      pid = fork
      exec(cmd) if pid.nil?
      Process.waitpid(pid)
      $?
    end

    def puts_delimiter(text)
      delimiter = ('=' * 78).colorize(:color => :black, :background => :white)
      puts delimiter
      puts text.colorize(:color => :black, :background => :white)
      puts delimiter
    end
  end
end
