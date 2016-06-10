# encoding: utf-8
# a2obrew settings

A2O_PATH = File.expand_path(File.dirname(__FILE__))

ICU_NATIVE_DIR = `uname`.start_with?('Darwin') ? 'buildMac' : 'buildLinux'

# rubocop:disable Metrics/LineLength
A2OCONF = {
  targets: {
    debug: {
      # :cppflags => '-g -O0 -DDEBUG',
      cppflags: '-O0 -DDEBUG',
      lflags: '-O0'
    },
    release: {
      cppflags: '-O2',
      lflags: '-Oz'
    },
    profile: {
      cppflags: '-O0 -DDEBUG --tracing',
      lflags: '-O0'
    }
  },
  depends: {
    path: "#{A2O_PATH}/depends",
    projects: [
      {
        name: 'libbsd',
        path: 'libbsd',
        repository_uri: 'git@github.com:tomboinc/libbsd.git',
        branch: 'feature/emscripten',
        autogen: './autogen',
        configure: 'emconfigure %{project_path}/configure --prefix=%{emscripten_system_local_path} --disable-shared CFLAGS="%{cppflags}"',
        build: 'make -j8',
        install: 'make install',
        clean: 'make clean'
      },
      {
        name: 'blocks-runtime',
        path: 'libclosure',
        repository_uri: 'git@github.com:tomboinc/libclosure.git',
        build_path: '%{project_path}',
        build: 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make',
        install: 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make install',
        clean: 'BUILD=%{build_target_path} make clean'
      },
      {
        name: 'objc4',
        path: 'objc4',
        repository_uri: 'git@github.com:tomboinc/objc4.git',
        branch: 'feature/emscripten',
        build_path: '%{project_path}',
        build: 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make -j8',
        install: 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make install',
        clean: 'BUILD=%{build_target_path} make clean'
      },
      {
        name: 'icu',
        path: 'icu',
        repository_uri: 'git@github.com:fchiba/icu.git',
        branch: 'prebuilt',
        configure: <<CONFIGURE,
emconfigure \
  %{project_path}/source/configure \
  --enable-static \
  --disable-shared \
  --disable-icuio \
  --disable-layout \
  --disable-tests \
  --disable-samples \
  --disable-extras \
  --disable-tools \
  --with-data-packaging=archive \
  --prefix=%{emscripten_system_local_path} \
  --with-cross-build=`pwd`/../#{ICU_NATIVE_DIR} \
  CPPFLAGS="%{cppflags} -DUCONFIG_NO_LEGACY_CONVERSION=1 -DUCONFIG_NO_COLLATION=1 -DUCONFIG_NO_TRANSLITERATION=1"
CONFIGURE
        build_path: '%{project_path}/buildEmscripten%{target}',
        build_target_path: '%{project_path}/buildEmscripten%{target}',
        build: <<BUILD,
emmake make ARFLAGS=rv -j8
opt-static-lib lib/libicui18n.a ../public_funcs.txt
opt-static-lib lib/libicuuc.a
BUILD
        install: 'make install'
      },
      {
        name: 'libdispatch',
        path: 'libdispatch',
        repository_uri: 'git@github.com:tomboinc/libdispatch.git',
        branch: 'feature/emscripten',
        build_path: '%{project_path}',
        build: 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make -j8',
        install: 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make install',
        clean: 'BUILD=%{build_target_path} make clean'
      },
      {
        # NOTE: openssl doesn't support target
        name: 'openssl',
        path: 'openssl',
        repository_uri: 'git@github.com:gunyarakun/openssl.git',
        branch: 'feature/emscripten',
        configure: 'emconfigure sh %{project_path}/Configure -no-asm no-ssl3 no-comp no-hw no-engine enable-deprecated no-shared no-dso no-gmp --openssldir=%{emscripten_system_local_path} linux-generic32',
        build_path: '%{project_path}',
        build_target_path: '%{project_path}',
        build: 'emmake make build_libs -j8',
        install: 'emmake make install_emscripten',
        clean: 'make clean'
      },
      {
        name: 'freetype',
        path: 'freetype',
        repository_uri: 'git@github.com:fchiba/freetype.git',
        branch: 'master',
        configure: 'emconfigure %{project_path}/configure --prefix=%{emscripten_system_local_path} --disable-shared --with-zlib=no --with-png=no CPPFLAGS="%{cppflags}"',
        build: 'emmake make -j8',
        install: 'emmake make install',
        clean: 'emmake make clean'
      },
      {
        name: 'Foundation',
        path: 'Foundation',
        repository_uri: 'git@github.com:tomboinc/Foundation.git',
        branch: 'feature/emscripten',
        autogen: 'BUILD_DIR=%{build_target_path} make install_header_only',
        build_path: '%{project_path}',
        build: 'STYLE_CPPFLAGS="%{cppflags}" STYLE_LFLAGS="%{lflags}" BUILD_DIR=%{build_target_path} make -j8',
        install: 'STYLE_CPPFLAGS="%{cppflags}" STYLE_LFLAGS="%{lflags}" BUILD_DIR=%{build_target_path} make install',
        clean: 'BUILD_DIR=%{build_target_path} make clean',
        frameworks: %w(
          System/CFNetwork
          System/CoreFoundation
          System/Foundation
          System/Security
        )
      },
      {
        name: 'A2OFrameworks',
        path: 'A2OFrameworks',
        repository_uri: 'git@github.com:tomboinc/A2OFrameworks.git',
        branch: 'master',
        autogen: 'BUILD_DIR=%{build_target_path} make install_header_only',
        build_path: '%{project_path}',
        build: 'STYLE_CPPFLAGS="%{cppflags}" STYLE_LFLAGS="%{lflags}" BUILD_DIR=%{build_target_path} make -j8',
        install: 'STYLE_CPPFLAGS="%{cppflags}" STYLE_LFLAGS="%{lflags}" BUILD_DIR=%{build_target_path} make install',
        clean: 'BUILD_DIR=%{build_target_path} make clean',
        frameworks: %w(
          Accounts
          AdSupport
          AudioToolbox
          AVFoundation
          CoreAudio
          CoreLocation
          GameKit
          ImageIO
          OpenGLES
          MapKit
          MobileCoreServices
          MultipeerConnectivity
          Social
          SystemConfiguration
          TomboAFNetworking
          TomboKit
          StoreKit
        )
      },
      {
        name: 'cocotron',
        path: 'cocotron',
        repository_uri: 'git@github.com:tomboinc/cocotron.git',
        branch: 'feature/emscripten',
        autogen: 'BUILD_DIR=%{build_target_path} make install_header_only',
        build_path: '%{project_path}',
        build: 'STYLE_CPPFLAGS="%{cppflags}" STYLE_LFLAGS="%{lflags}" BUILD_DIR=%{build_target_path} make -j8',
        install: 'STYLE_CPPFLAGS="%{cppflags}" STYLE_LFLAGS="%{lflags}" BUILD_DIR=%{build_target_path} make install',
        clean: 'BUILD_DIR=%{build_target_path} make clean',
        frameworks: %w(
          CommonCrypto
          CoreData
          CoreGraphics
          CoreText
          Onyx2D
          QuartzCore
        )
      },
      {
        name: 'Chameleon',
        path: 'Chameleon',
        repository_uri: 'git@github.com:tomboinc/Chameleon.git',
        branch: 'feature/with_cocotron',
        autogen: 'BUILD_DIR=%{build_target_path} make install_header_only',
        build_path: '%{project_path}',
        build: 'STYLE_CPPFLAGS="%{cppflags}" STYLE_LFLAGS="%{lflags}" BUILD_DIR=%{build_target_path} make -j8',
        install: 'STYLE_CPPFLAGS="%{cppflags}" STYLE_LFLAGS="%{lflags}" BUILD_DIR=%{build_target_path} make install',
        clean: 'BUILD_DIR=%{build_target_path} make clean',
        frameworks: %w(
          UIKit
        )
      }
    ]
  },
  xcodebuild: {
    emscripten: {
      file_packager: {
        separate_metadata: false
      },
      emcc: {
        separate_asm: true
      }
    },
    static_link_frameworks: %w(
      UIKit Security ImageIO AudioToolbox CommonCrypto SystemConfiguration
      CoreGraphics QuartzCore CFNetwork OpenGLES Onyx2D CoreText
      Social AVFoundation StoreKit CoreFoundation MapKit GameKit MultipeerConnectivity
    ),
    dynamic_link_frameworks: %w(
      Foundation
    )
  }
}.freeze
