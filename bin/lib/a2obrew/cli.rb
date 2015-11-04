#!/usr/bin/env ruby
# encoding: utf-8

require 'thor'
require 'mkmf'; module MakeMakefile::Logging; @logfile = File::NULL; end
require 'colorize'
require 'fileutils'

INIT_SCRIPT = <<EOT
echo "FIXME: Implement rbenv init"
EOT

module A2OBrew
  class CLI < Thor
    desc 'init [OPTIONS]', 'show shell script enables shims and autocompletion'
    def init(*args)
      print = false
      no_rehash = false

      args.arch {|arg|
        if arg == '-'
          print = true
        elsif arg == '--no-rehash'
          no_rehash = true
        end
      }
      puts INIT_SCRIPT
    end

    desc 'env', 'show shell script loading emscripten environment value'
    def env
      puts "source #{emsdk_path}/emsdk_env.sh"
    end

    desc 'update [PROJECT_NAME]', 'update a2obrew and dependent repositories'
    def update(proj_name=nil)
      if proj_name.nil? or proj[:name] == 'a2obrew'
        git_update(a2obrew_path, nil, nil)
      end
      # TODO: reload A2OCONF for reloading config
      depends = A2OCONF[:depends]
      depends[:projects].each {|proj|
        unless proj_name.nil? or proj[:name] == proj_name
          next
        end
        proj_path = "#{depends[:path]}/#{proj[:path]}"
        git_update(proj_path, proj[:branch], proj[:repository_uri])
      }
    end

    desc 'autogen PROJECT_NAME', 'autogen dependent repositories'
    def autogen(proj_name=nil)
      check_emsdk_env
      depends = A2OCONF[:depends]
      depends[:projects].each {|proj|
        unless proj_name.nil? or proj[:name] == proj_name
          next
        end
        proj_path = "#{depends[:path]}/#{proj[:path]}"
        # run autogen
        if proj[:autogen]
          cmd_exec "cd #{proj_path} && #{proj[:autogen]}"
        end
      }
    end

    desc 'configure PROJECT_NAME', 'configure dependent repositories'
    method_option :target, :aliases => '-t', :default => 'release', :desc => 'Build target (ex. release)'
    def configure(proj_name=nil)
      check_emsdk_env
      target = options[:target]
      depends = A2OCONF[:depends]
      depends[:projects].each {|proj|
        unless proj_name.nil? or proj[:name] == proj_name
          next
        end
        proj_path = "#{depends[:path]}/#{proj[:path]}"
        proj_build_path = build_path(target, proj, proj_path)

        # configure
        if proj[:configure]
          mkdir_p(proj_build_path)
          configure = proj[:configure] % {
            :project_path => proj_path,
            :emsdk_path => emsdk_path,
          }
          cmd_exec "cd #{proj_build_path} && #{configure}"
        end
      }
    end

    desc 'build PROJECT_NAME', 'build dependent repositories'
    method_option :target, :aliases => '-t', :default => 'release', :desc => 'Build target (ex. release)'
    def build(proj_name=nil)
      check_emsdk_env
      target = options[:target]
      depends = A2OCONF[:depends]
      depends[:projects].each {|proj|
        unless proj_name.nil? or proj[:name] == proj_name
          next
        end

        proj_path = "#{depends[:path]}/#{proj[:path]}"
        proj_build_path = build_path(target, proj, proj_path)

        unless File.directory?(proj_build_path)
          # mkdir build path for target and execute configure
          FileUtils.mkdir_p(proj_build_path)
        end

        # build!
        if proj[:build]
          if proj[:frameworks]
            mkdir_p(proj_build_path)
            proj[:frameworks].each {|framework|
              cmd_exec "cd #{proj_path}/#{framework} && BUILD_DIR=#{proj_build_path} #{proj[:build]}"
            }
          else
            cmd_exec "cd #{proj_build_path} && #{proj[:build]}"
          end
        end
      }
    end

    desc 'install PROJECT_NAME', 'install dependent repositories'
    method_option :target, :aliases => '-t', :default => 'release', :desc => 'Build target (ex. release)'
    def install(proj_name=nil)
      check_emsdk_env
      target = options[:target]
      depends = A2OCONF[:depends]
      depends[:projects].each {|proj|
        unless proj_name.nil? or proj[:name] == proj_name
          next
        end
        proj_path = "#{depends[:path]}/#{proj[:path]}"
        proj_build_path = build_path(target, proj, proj_path)

        # install
        if proj[:install]
          if proj[:frameworks]
            proj[:frameworks].each {|framework|
              cmd_exec "cd #{proj_path}/#{framework} && BUILD_DIR=#{proj_build_path} #{proj[:install]}"
            }
          else
            cmd_exec "cd #{proj_build_path} && #{proj[:install]}"
          end
        end
      }
    end

    desc 'clean PROJECT_NAME', 'clean dependent repositories'
    def clean(proj_name=nil)
      target = options[:target]
      depends = A2OCONF[:depends]
      depends[:projects].each {|proj|
        unless proj_name.nil? or proj[:name] == proj_name
          next
        end
        proj_path = "#{depends[:path]}/#{proj[:path]}"
        proj_build_path = build_path(target, proj, proj_path)

        if proj[:clean]
          cmd_exec "cd #{proj_build_path} && #{proj[:clean]}"
        end
      }
    end

    private

    # die unless emcc
    def check_emsdk_env
      if find_executable('emcc').nil?
        error_exit("Cannot find emcc. Execute 'eval $(#{$PROGRAM_NAME} env)'")
      end
    end

    # git pull if remote updated 
    def git_update(root_path, branch_name, repository_uri)
      if File.directory?(root_path)
        # git clone has already done

        git_path = "#{root_path}/.git"
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
          cmd_exec "#{git_command} pull"
          if $CHILD_STATUS != 0
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

    def build_path(target, project_conf, project_path)
      # load non-standard build_path from conf
      # mainly for openssl which uses non-standard perl configure script X(
      if project_conf[:build_path]
        project_conf[:build_path] % {
          :project_path => project_path
        }
      else
        "#{a2obrew_path}/build/#{target}/#{project_conf[:path]}"
      end
    end

    def error_exit(message)
      puts "a2obrew: #{message}"
      exit(1)
    end

    def mkdir_p(path)
      unless File.directory?(path)
        FileUtils.mkdir_p(path)
      end
    end

    def cmd_exec(cmd)
      delimiter = ('=' * 78).colorize(:color => :black, :background => :white)
      puts delimiter
      puts cmd.colorize(:color => :black, :background => :white)
      puts delimiter
      puts `#{cmd}`
    end
  end
end
