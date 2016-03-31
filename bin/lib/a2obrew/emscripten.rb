require_relative 'git'
require_relative 'cli_base'

module A2OBrew
  class Emscripten < CLIBase
    REPOSITORYS = [
      {
        path: 'emsdk',
        branch: 'feature/objc',
        git_url: 'git@github.com:tomboinc/emsdk'
      },
      {
        path: 'emsdk/emscripten/a2o',
        branch: 'feature/objc',
        git_url: 'git@github.com:tomboinc/emscripten.git'
      },
      {
        path: 'emsdk/clang/fastcomp/src',
        branch: 'feature/objc',
        git_url: 'git@github.com:tomboinc/emscripten-fastcomp.git'
      },
      {
        path: 'emsdk/clang/fastcomp/src/tools/clang',
        branch: 'feature/objc',
        git_url: 'git@github.com:tomboinc/emscripten-fastcomp-clang.git'
      }
    ].freeze

    desc 'update', 'update emscripten repositories'
    def update
      update_repositories

      Util.cmd_exec("cd #{a2obrew_path}/emsdk && ./emsdk install sdk-a2o-64bit && ./emsdk activate sdk-a2o-64bit && bash -c 'source ./emsdk_env.sh && emcc --clear-cache --clear-ports && emcc -O3 -s USE_LIBPNG=1 -s USE_ZLIB=1 #{a2obrew_path}/scripts/install-emscripten-ports.c'") # rubocop:disable Metrics/LineLength
    rescue CmdExecException => e
      error_exit(e.message, e.exit_status)
    end

    private

    def update_repositories
      REPOSITORYS.each do |repo|
        Git.update("#{a2obrew_path}/#{repo[:path]}", repo[:branch], repo[:git_url])
      end
    rescue CmdExecException => e
      error_exit(e.message, e.exit_status)
    end
  end
end
