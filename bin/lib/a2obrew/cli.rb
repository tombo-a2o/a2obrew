#!/usr/bin/env ruby
# encoding: utf-8

require 'thor'

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

    desc 'update', 'update a2obrew and all dependent repositories'
    def update
      depends = A2OCONF[:depends]
      depends[:projects].each {|proj|
        proj_path = "#{depends[:path]}/#{proj[:path]}"
        git_update(proj_path, proj[:branch], proj[:repository_uri])
      }
      git_update(a2obrew_path, nil, nil)
    end

    private

    def git_update(root_path, branch_name, repository_uri)
      if File.directory?(root_path)
        # git clone has already done

        git_path = "#{root_path}/.git"
        git_command = "git --git-dir=#{git_path} --work-tree=#{root_path}"

        # Change current branch if needed
        current_branch = `#{git_command} rev-parse --abbrev-ref HEAD`

        if branch_name and current_branch != branch_name
          puts `#{git_command} checkout #{branch_name}`
        end

        # check the repository is up to date or not
        puts `#{git_command} remote update`
        local = `#{git_command} rev-parse @`
        remote = `#{git_command} rev-parse @{u}`
        base = `#{git_command} merge-base @ @{u}`

        if local == remote
          puts "#{root_path} is up to date."
        elsif local == base
          # git pull if needed
          puts `#{git_command} pull`
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
        puts `git clone #{repository_uri} #{branch_option} #{root_path}`
      end
    end

    def a2obrew_path
      File.expand_path('../../../..', __FILE__)
    end

    def emsdk_path
      "#{a2obrew_path}/emsdk"
    end

    def error_exit(message)
      puts "a2obrew: #{message}"
      exit(1)
    end
  end
end
