# frozen_string_literal: true
require_relative 'util'

module A2OBrew
  class Git
    # git pull if remote updated
    def self.update(root_path, branch_name, repository_uri) # rubocop:disable Metrics/PerceivedComplexity
      git_path = "#{root_path}/.git"
      if File.directory?(root_path) && File.directory?(git_path)
        # git clone has already done

        git_command = "git --git-dir=#{git_path} --work-tree=#{root_path}"

        # Change current branch if needed
        current_branch = `#{git_command} rev-parse --abbrev-ref HEAD`

        if branch_name && current_branch != branch_name
          Util.cmd_exec "#{git_command} checkout #{branch_name}",
                        "fail to change the branch from #{current_branch} to #{branch_name}"
        end

        # check the repository is up to date or not
        Util.cmd_exec "#{git_command} remote update", 'fail to git remote update'
        local = `#{git_command} rev-parse @`
        remote = `#{git_command} rev-parse @{u}`
        base = `#{git_command} merge-base @ @{u}`

        if local == remote
          puts "#{root_path} is up to date."
        elsif local == base
          # git pull if needed
          Util.cmd_exec "#{git_command} pull", "git pull fails on #{root_path}"
        elsif remote == base
          error_exit "You must do 'git push' on #{root_path}"
        else
          # diverged
          error_exit "You must update #{root_path} yourself"
        end
      else
        # git clone hasn't done yet, so do git clone
        branch_option = if branch_name
                          "--branch #{branch_name}"
                        else
                          ''
                        end
        Util.cmd_exec "git clone #{repository_uri} #{branch_option} #{root_path}",
                      "git clone fails from #{repository_uri} with the branch #{branch_name} to #{root_path}"
      end
    end
  end
end
