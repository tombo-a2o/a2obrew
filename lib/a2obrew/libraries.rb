# frozen_string_literal: true

require_relative 'git'
require_relative 'util'
require_relative 'cli_base'

module A2OBrew
  class Libraries < CLIBase
    desc 'upgrade PROJECT_NAMES', 'upgrade (update & build) dependent libraries'
    method_option :target, aliases: '-t', default: 'release', desc: 'Build target (ex. release)'
    def upgrade(*proj_names)
      target = options[:target]
      upgrade_main(proj_names, target)
    end

    desc 'update PROJECT_NAMES', 'update dependent repositories'
    def update(*proj_names)
      update_main(proj_names)
    end

    desc 'autogen PROJECT_NAMES', 'autogen dependent repositories'
    method_option :target, aliases: '-t', default: 'release', desc: 'Build target (ex. release)'
    def autogen(*proj_names)
      target = options[:target]
      build_main(:autogen, proj_names, target)
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

    no_commands do
      def upgrade_main(proj_names, target)
        update_main(proj_names)
        build_main(:autogen, proj_names)
        build_main(:configure, proj_names, target)
        build_main(:build, proj_names, target)
        build_main(:install, proj_names, target)
      end

      def update_main(proj_names)
        depends = A2OCONF[:depends]
        depends[:projects].each do |proj|
          @current_command = "a2obrew libraries update #{proj[:name]}"

          next unless proj_names.empty? || proj_names.include?(proj[:name])
          proj_path = "#{depends[:path]}/#{proj[:path]}"
          begin
            Git.update(proj_path, proj[:branch], proj[:repository_uri])
          rescue CmdExecException => e
            error_exit(e.message, e.exit_status)
          end
        end
      end

      # TODO: Refactor to rubocop compliant
      def build_main(command, proj_names, target = nil) # rubocop:disable Metrics/PerceivedComplexity,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/LineLength
        check_emscripten_env
        check_target(target)
        depends = A2OCONF[:depends]
        depends[:projects].each do |proj|
          @current_command = "a2obrew libraries #{command} #{proj[:name]}"

          next unless proj_names.empty? || proj_names.include?(proj[:name])
          next if proj[command].nil?

          proj_base_path = "#{depends[:path]}/#{proj[:path]}"

          proj_paths = if proj[:frameworks]
                         proj[:frameworks].map { |framework| "#{proj_base_path}/#{framework}" }
                       else
                         [proj_base_path]
                       end

          proj_paths.each do |proj_path|
            work_path = if command == :autogen
                          proj_path
                        else
                          build_path(proj_path, target, proj)
                        end
            build_target_path = build_target_path(proj_path, target, proj)

            if command == :clean
              next unless File.exist?(work_path)
            else
              Util.mkdir_p(work_path)
              Util.mkdir_p(build_target_path)
            end

            cmd = format(proj[command], project_path: proj_path,
                                        build_target_path: build_target_path,
                                        emscripten_system_local_path: emscripten_system_local_path,
                                        cppflags: target ? A2OCONF[:targets][target.intern][:cppflags] : nil,
                                        lflags: target ? A2OCONF[:targets][target.intern][:lflags] : nil)

            Util.cmd_exec "cd #{work_path} && #{cmd}", "Build Error: stop a2obrew libraries #{command} #{proj[:name]}"
          end
        end
      rescue CmdExecException => e
        error_exit(e.message, e.exit_status)
      end
    end

    def self.completions(commands)
      puts_commands if commands.empty?

      case commands[0].intern
      when :update, :autogen
        puts_build_completion(false)
      when :configure, :build, :install, :clean
        puts_build_completion(true)
      end
    end

    def self.project_names
      A2OCONF[:depends][:projects].map { |proj| proj[:name] }
    end

    def self.puts_build_completion(with_target = true)
      if with_target
        A2OCONF[:targets].each_key do |target|
          puts "--target=#{target}"
        end
      end
      puts project_names.join("\n")
      exit(0)
    end

    private_class_method :project_names, :puts_build_completion

    private

    def check_target(target)
      error_exit(<<~INVALID_TARGET) unless target.nil? || A2OCONF[:targets].key?(target.intern)
        Invalid target '#{target}'.
        You must specify #{A2OCONF[:targets].keys.join('/')}.
      INVALID_TARGET
    end

    def build_path(project_path, target, project_conf)
      if project_conf[:build_path]
        format(project_conf[:build_path], project_path: project_path,
                                          target: target)
      else
        "#{project_path}/build/#{target}"
      end
    end

    def build_target_path(project_path, target, project_conf)
      if project_conf[:build_target_path]
        format(project_conf[:build_target_path], project_path: project_path,
                                                 target: target)
      else
        "#{project_path}/build/#{target}"
      end
    end
  end
end
