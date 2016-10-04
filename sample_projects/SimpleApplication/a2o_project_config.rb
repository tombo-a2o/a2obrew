cc_flags = '-s FULL_ES2=1 -DGL_GLEXT_PROTOTYPES=1'
html_flags = '-s FULL_ES2=1 -s TOTAL_MEMORY=134217728'
# html_flags += ' --pre-js mem_check.js'

config = {
  version: 1,
  xcodeproj_path: 'SimpleApplication.xcodeproj',
  xcodeproj_target: 'SimpleApplication',
  a2o_targets: {
    debug: {
      xcodeproj_build_config: 'Debug',
      flags: {
        cc: "-O0 -DDEBUG=1 #{cc_flags}",
        html: "-O0 -s OBJC_DEBUG=1 #{html_flags} -emrun"
      },
      emscripten_shell_path: 'shell.html'
    },
    release: {
      xcodeproj_build_config: 'Release',
      flags: {
        cc: "-Oz #{cc_flags}",
        html: "-O2 #{html_flags}"
      },
      emscripten_shell_path: 'shell.html'
    },
    profile: {
      xcodeproj_build_config: 'Debug',
      flags: {
        cc: "-O0 -DDEBUG=1 #{cc_flags} --tracing",
        html: "-O0 -s OBJC_DEBUG=1 #{html_flags} --tracing"
      },
      emscripten_shell_path: 'shell.html'
    }
  }
}

# puts config

config
