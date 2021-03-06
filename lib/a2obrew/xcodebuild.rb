# frozen_string_literal: true

require_relative 'cli_base'
require_relative 'xcode2ninja'

module A2OBrew
  class XcodeBuild < CLIBase
    PROJECT_CONFIG_RB_PATH = 'a2o_project_config.rb'

    def self.completions(_commands)
      # FIXME: implement
    end

    desc 'build', 'build application with config file'
    method_option :clean, type: :boolean, aliases: '-c', default: false, desc: 'Clean'
    method_option :project_config, aliases: '-p', desc: 'Project config ruby path'
    method_option :target, aliases: '-t', default: 'release', desc: 'Build target for a2o(ex. release)'
    method_option :jobs, type: :numeric, aliases: '-j', desc: 'the number of jobs to run simultaneously'
    method_option :keep, type: :numeric, aliases: '-k', desc: 'keep going until N jobs fail'
    method_option :xcodeproj_target, desc: 'Build target for xcodeproj'
    def build
      check_emscripten_env

      ninja_path = generate_ninja_build(options)
      execute_ninja_command(ninja_path, options)
    end

    default_task :build

    private

    def read_project_config(path)
      if File.exist?(path)
        config = eval File.read(path) # rubocop:disable Security/Eval
        raise Informative, "#{BUILD_CONFIG_RB_PATH} version should be 1" unless config[:version] == 1
        config
      else
        {}
      end
    end

    def load_project_config(project_config_path)
      error_exit "Specified #{project_config_path} not found" unless project_config_path.nil? || File.exist?(project_config_path)

      project_config_path ||= PROJECT_CONFIG_RB_PATH

      proj_config = if File.exist?(project_config_path)
                      read_project_config(project_config_path)
                    else
                      {}
                    end

      [project_config_path, proj_config]
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

      error_exit('Specify valid .xcodeproj path') unless FileTest.directory?(xcodeproj_path)

      xcodeproj_path
    end

    def find_xcodeproj_build_config(active_project_config, a2o_target)
      xcodeproj_build_config = active_project_config[:xcodeproj_build_config]
      unless xcodeproj_build_config
        xcodeproj_build_config = {
          debug: 'Debug',
          release: 'Release'
        }[a2o_target]

        error_exit('Cannot determine xcodeproj_build_config') unless xcodeproj_build_config
      end

      xcodeproj_build_config
    end

    def generate_ninja_build(options)
      a2o_target = options[:target].intern
      proj_config_path, proj_config = load_project_config(options[:project_config])
      xcodeproj_path = search_xcodeproj_path(options[:xcodeproj_path] || proj_config[:xcworkspace_path] || proj_config[:xcodeproj_path])
      xcodeproj_name = options[:xcodeproj_name] || proj_config[:xcodeproj_name]
      xcodeproj_target = options[:xcodeproj_target] ||
                         proj_config[:xcodeproj_target] ||
                         File.basename(xcodeproj_path, '.xcodeproj')
      active_project_config = fetch_active_project_config(proj_config, a2o_target)
      xcodeproj_build_config = find_xcodeproj_build_config(active_project_config, a2o_target)
      ninja_path = "a2o/ninja/#{a2o_target}.ninja.build"

      Util.puts_delimiter("# Generate #{ninja_path}")
      puts <<~NINJA_A2O
        a2o:
          target: #{a2o_target}
          proj_config_path: #{proj_config_path}
      NINJA_A2O
      puts <<~NINJA_XCODEPROJ
        xcodeproj:
          xcodeproj_path: #{xcodeproj_path}
          xcodeproj_name: #{xcodeproj_name}
          xcodeproj_target: #{xcodeproj_target}
          xocdeproj_build_config: #{xcodeproj_build_config}
      NINJA_XCODEPROJ
      xn = Xcode2Ninja.new(xcodeproj_path, xcodeproj_name, a2obrew_path)
      gen_paths = xn.xcode2ninja('a2o/ninja', xcodeproj_target,
                                 xcodeproj_build_config, active_project_config, a2o_target)
      gen_paths.each do |path|
        puts "Generate #{path}"
      end

      ninja_path
    end

    def fetch_active_project_config(proj_config, a2o_target)
      begin
        active_project_config = proj_config[:a2o_targets][a2o_target]
      rescue StandardError
        active_project_config = {}
      end
      active_project_config
    end

    BUILD_LOG_PATH = 'a2o/build.log'
    UNRESOLVED_SYMBOL_LOG_PATH = 'a2o/unresolved'

    def execute_ninja_build(ninja_path, options)
      build_log = File.open(BUILD_LOG_PATH, 'w')
      jobs = "-j #{options[:jobs]}" if options[:jobs]
      keep = "-k #{options[:keep]}" if options[:keep]
      output = []
      Util.cmd_exec("ninja -v -f #{ninja_path} #{jobs} #{keep}", 'ninja build error') do |output_buffer|
        print output_buffer
        build_log.write Util.filter_ansi_esc(output_buffer)
        output << output_buffer
      end

      unresolved = []
      output.join('').each_line do |line|
        case line.chomp
        when / unresolved symbol: (.+)\z/
          unresolved << Regexp.last_match(1)
        end
      end
      File.open(UNRESOLVED_SYMBOL_LOG_PATH, 'w').write(unresolved.sort.join("\n"))
    end

    def execute_ninja_command(ninja_path, options)
      if options[:clean]
        Util.cmd_exec "ninja -v -f #{ninja_path} -t clean", 'ninja clean error'
        Util.cmd_exec "rm -f #{ninja_path}", "remove ninja file error: #{ninja_path}"
      else
        execute_ninja_build(ninja_path, options)
      end
    rescue CmdExecException => e
      error_exit(e.message, e.exit_status)
    end
  end
end
