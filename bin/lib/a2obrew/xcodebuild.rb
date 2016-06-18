require_relative 'cli_base'
require_relative 'xcode2ninja'

module A2OBrew
  class XcodeBuild < CLIBase # rubocop:disable Metrics/ClassLength
    PROJECT_CONFIG_RB_PATH = 'a2o_project_config.rb'.freeze

    def self.completions(_commands)
      # FIXME: implement
    end

    desc 'build', 'build application with config file'
    method_option :clean, type: :boolean, aliases: '-c', default: false, desc: 'Clean'
    method_option :project_config, aliases: '-p', desc: 'Project config ruby path'
    method_option :target, aliases: '-t', default: 'release', desc: 'Build target for a2o(ex. release)'
    method_option :jobs, type: :numeric, aliases: '-j', desc: 'the number of jobs to run simultaneously'
    def build
      check_emsdk_env

      ninja_path = generate_ninja_build(options)
      execute_ninja_command(ninja_path, options)
    end

    default_task :build

    private

    def read_project_config(path)
      if File.exist?(path)
        config = eval File.read(path) # rubocop:disable Lint/Eval
        unless config[:version] == 1
          raise Informative, '#{BUILD_CONFIG_RB_PATH} version should be 1'
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

      unless FileTest.directory?(xcodeproj_path)
        error_exit('Specify valid .xcodeproj path')
      end

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

    def generate_ninja_build(options) # rubocop:disable Metrics/MethodLength
      a2o_target = options[:target].intern
      proj_config_path, proj_config = load_project_config(options[:project_config])
      xcodeproj_path = search_xcodeproj_path(options[:xcodeproj_path])
      xcodeproj_target = proj_config[:xcodeproj_target] || File.basename(xcodeproj_path, '.xcodeproj')
      active_project_config = fetch_active_project_config(proj_config, a2o_target)
      xcodeproj_build_config = find_xcodeproj_build_config(active_project_config, a2o_target)
      ninja_path = "ninja/#{a2o_target}.ninja.build"

      Util.puts_delimiter("# Generate #{ninja_path}")
      puts <<EOF
a2o:
  target: #{a2o_target}
  proj_config_path: #{proj_config_path}
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

    def execute_ninja_command(ninja_path, options)
      if options[:clean]
        Util.cmd_exec "ninja -v -f #{ninja_path} -t clean", 'ninja clean error'
        Util.cmd_exec "rm -f #{ninja_path}", "remove ninja file error: #{ninja_path}"
      else
        jobs = "-j #{options[:jobs]}" if options[:jobs]
        Util.cmd_exec "ninja -v -f #{ninja_path} #{jobs}", 'ninja build error'
      end
    rescue CmdExecException => e
      error_exit(e.message, e.exit_status)
    end
  end
end
