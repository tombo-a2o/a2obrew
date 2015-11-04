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
      depends[:projects].each{|proj|
        proj_path = "#{depends[:path]}/#{proj[:path]}"

        if File.directory?(proj_path)
          # git clone has already done

          git_path = "#{proj_path}/.git"
          git_command = "git --git-dir=#{git_path} --work-tree=#{proj_path}"

          # Change current branch if needed
          current_branch = `#{git_command} rev-parse --abbrev-ref HEAD`

          if proj[:branch] and current_branch != proj[:branch]
            puts `#{git_command} checkout #{proj[:branch]}`
          end

          # check the repository is up to date or not
          puts `#{git_command} remote update`
          local = `#{git_command} rev-parse @`
          remote = `#{git_command} rev-parse @{u}`
          base = `#{git_command} merge-base @ @{u}`

          if local == remote
            puts "#{proj_path} is up to date."
          elsif local == base
            # git pull if needed
            puts `#{git_command} pull`
            if $CHILD_STATUS != 0
              error_exit "git pull fails on #{proj_path}"
            end
          elsif remote == base
            error_exit "You must do 'git push' on #{proj_path}"
          else
            # diverged
            error_exit "You must update #{proj_path} yourself"
          end
        else
          # git clone hasn't done yet, so do git clone
          if proj[:branch]
            branch_option = "--branch #{proj[:branch]}"
          else
            branch_option = ''
          end
          puts `git clone #{proj[:repository_uri]} #{branch_option} #{proj_path}`
        end
      }
    end

    private

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
