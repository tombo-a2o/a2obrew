# frozen_string_literal: true

require_relative 'git'
require_relative 'cli_base'

module A2OBrew
  class Emscripten < CLIBase
    REPOSITORYS = [
      {
        path: 'emscripten/emscripten',
        branch: 'feature/objc',
        git_url: 'git@github.com:tombo-a2o/emscripten.git'
      },
      {
        path: 'emscripten/fastcomp/src',
        branch: 'feature/objc',
        git_url: 'git@github.com:tombo-a2o/emscripten-fastcomp.git'
      },
      {
        path: 'emscripten/fastcomp/src/tools/clang',
        branch: 'feature/objc',
        git_url: 'git@github.com:tombo-a2o/emscripten-fastcomp-clang.git'
      },
      {
        path: 'emscripten/binaryen',
        branch: 'master',
        git_url: 'git@github.com:tombo-a2o/binaryen.git'
      }
    ].freeze

    def self.completions(_commands)
      # FIXME: implement
    end

    desc 'update', 'update emscripten repositories'
    def update
      update_main
    end

    desc 'build', 'build emscripten repositories'
    def build
      build_main
    end

    desc 'upgrade', 'update & build emscripten repositories'
    def upgrade
      upgrade_main
    end

    no_commands do # rubocop:disable Metrics/BlockLength
      def update_main
        REPOSITORYS.each do |repo|
          Git.update("#{a2obrew_path}/#{repo[:path]}", repo[:branch], repo[:git_url])
        end
      rescue CmdExecException => e
        error_exit(e.message, e.exit_status)
      end

      def emenv_sh
        <<~EMENV_SH
          export PATH=#{emscripten_path}/fastcomp/build/bin:#{emscripten_path}/emscripten:#{lang_path}/python2/bin:#{lang_path}/ruby/bin:#{lang_path}/node/bin:#{lang_path}/node/lib/node_modules/a2obrew/node_modules/.bin:$PATH
          export EM_CONFIG=#{emscripten_path}/.emscripten
          export EM_PORTS=#{emscripten_path}/.emscripten_ports
          export EM_CACHE=#{emscripten_path}/.emscripten_cache
          export EMSCRIPTEN=#{emscripten_path}/emscripten
        EMENV_SH
      end

      def dot_emscripten
        # NOTE: .emscripten is a python script.
        llvm_root = "#{emscripten_path}/fastcomp/build/bin"
        emscripten_root = "#{emscripten_path}/emscripten"
        binaryen_root = "#{emscripten_path}/binaryen"
        optimizer = "#{emscripten_path}/optimizer/optimizer"
        node = "#{lang_path}/node/bin/node"
        temp_dir = "#{emscripten_path}/temp"
        Util.mkdir_p(temp_dir)
        <<~DOT_EMSCRIPTEN
          LLVM_ROOT = '#{llvm_root}'
          EMSCRIPTEN_ROOT = '#{emscripten_root}'
          EMSCRIPTEN_NATIVE_OPTIMIZER = '#{optimizer}'
          NODE_JS = '#{node}'
          SPIDERMONKEY_ENGINE = ''
          V8_ENGINE = ''
          TEMP_DIR = '#{temp_dir}'
          COMPILER_ENGINE = NODE_JS
          JS_ENGINES = [NODE_JS]
          BINARYEN_ROOT = '#{binaryen_root}'
        DOT_EMSCRIPTEN
      end

      def build_main
        File.open("#{emscripten_path}/.emscripten", 'w') do |f|
          f.write dot_emscripten
        end

        File.open("#{emscripten_path}/emenv.sh", 'w') do |f|
          f.write emenv_sh
        end
        FileUtils.chmod('+x', "#{emscripten_path}/emenv.sh")

        # rubocop: disable Metrics/LineLength
        Util.cmd_exec(
          "mkdir -p #{emscripten_path}/fastcomp/build && "\
          "cd #{emscripten_path}/fastcomp/build && "\
          "cmake -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE=RelWithDebInfo '-DPYTHON_EXECUTABLE=#{lang_path}/python2/bin/python' '-DLLVM_TARGETS_TO_BUILD=X86;JSBackend' -DLLVM_INCLUDE_EXAMPLES=OFF -DCLANG_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_TESTS=OFF -DCLANG_INCLUDE_TESTS=OFF '#{emscripten_path}/fastcomp/src' && "\
          'make -j3 && '\
          "mkdir -p #{emscripten_path}/optimizer && "\
          "cd #{emscripten_path}/optimizer && "\
          "cmake -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE=RelWithDebInfo '-DPYTHON_EXECUTABLE=#{lang_path}/python2/bin/python' '#{emscripten_path}/emscripten/tools/optimizer' && "\
          'make -j3 && '\
          'source ../emenv.sh && '\
          'emcc --clear-cache --clear-ports && '\
          "emcc -O3 -s USE_LIBPNG=1 -s USE_ZLIB=1 '#{a2obrew_path}/scripts/install-emscripten-ports.c' && "\
          "cd #{emscripten_path}/binaryen && "\
          'cmake . && '\
          'make -j3'
        )
        # rubocop: enable Metrics/LineLength
      rescue CmdExecException => e
        error_exit(e.message, e.exit_status)
      end

      def upgrade_main
        update_main
        build_main
      end
    end
  end
end
