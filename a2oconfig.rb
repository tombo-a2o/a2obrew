# frozen_string_literal: true

# a2obrew settings

# rubocop:disable Metrics/LineLength

A2O_PATH = File.expand_path(__dir__)

ICU_NATIVE_DIR = `uname`.start_with?('Darwin') ? 'buildMac' : 'buildLinux'

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
        repository_uri: 'git@github.com:tombo-a2o/libbsd.git',
        branch: 'feature/emscripten',
        autogen: './autogen',
        configure: 'emconfigure %{project_path}/configure --prefix=%{emscripten_system_local_path} --disable-shared CFLAGS="%{cppflags}"',
        build: 'make -j8',
        install: 'make install',
        clean: 'make clean'
      },
      {
        name: 'libtiff',
        path: 'libtiff',
        repository_uri: 'git@github.com:tombo-a2o/libtiff.git',
        branch: 'emscripten',
        configure: 'emconfigure %{project_path}/configure --prefix=%{emscripten_system_local_path} --disable-shared CFLAGS="%{cppflags}"',
        build_path: '%{project_path}/buildEmscripten-%{target}',
        build_target_path: '%{project_path}/buildEmscripten-%{target}',
        build: 'make -j8',
        install: 'make install',
        clean: 'make clean'
      },
      {
        name: 'sqlite3',
        path: 'sqlite3',
        repository_uri: 'git@github.com:tombo-a2o/sqlite3.git',
        branch: 'master',
        build_path: '%{project_path}',
        build: 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make',
        install: 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make install',
        clean: 'BUILD=%{build_target_path} make clean'
      },
      {
        name: 'libclosure',
        path: 'libclosure',
        repository_uri: 'git@github.com:tombo-a2o/libclosure.git',
        build_path: '%{project_path}',
        build: 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make',
        install: 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make install',
        clean: 'BUILD=%{build_target_path} make clean'
      },
      {
        name: 'objc4',
        path: 'objc4',
        repository_uri: 'git@github.com:tombo-a2o/objc4.git',
        branch: 'feature/emscripten',
        build_path: '%{project_path}',
        build: 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make -j8',
        install: 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make install',
        clean: 'BUILD=%{build_target_path} make clean'
      },
      {
        name: 'icu',
        path: 'icu',
        repository_uri: 'git@github.com:tombo-a2o/icu.git',
        branch: 'prebuilt',
        configure: <<~CONFIGURE,
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
            CPPFLAGS="%{cppflags} -DUCONFIG_NO_LEGACY_CONVERSION=1 -DUCONFIG_NO_COLLATION=1"
        CONFIGURE
        build_path: '%{project_path}/buildEmscripten%{target}',
        build_target_path: '%{project_path}/buildEmscripten%{target}',
        build: <<~BUILD,
          emmake make ARFLAGS=rv -j8
          opt-static-lib lib/libicui18n.a ../public_funcs.txt
          opt-static-lib lib/libicuuc.a
        BUILD
        install: 'make install'
      },
      {
        name: 'libdispatch',
        path: 'libdispatch',
        repository_uri: 'git@github.com:tombo-a2o/libdispatch.git',
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
        repository_uri: 'git@github.com:tombo-a2o/openssl.git',
        branch: 'feature/emscripten',
        configure: 'emconfigure sh %{project_path}/Configure -no-asm no-ssl3 no-comp no-hw no-engine enable-deprecated no-shared no-dso no-gmp --openssldir=%{emscripten_system_local_path} linux-generic32',
        build_path: '%{project_path}',
        build_target_path: '%{project_path}',
        build: 'emmake make build_libs -j8',
        install: 'emmake make install_emscripten',
        clean: 'make clean'
      },
      {
        name: 'libxml2',
        path: 'libxml2',
        repository_uri: 'git@github.com:tombo-a2o/libxml2.git',
        branch: 'emscripten',
        autogen: 'mkdir -p m4 && autoreconf -i',
        configure: 'emconfigure %{project_path}/configure --with-http=no --with-ftp=no --with-python=no --with-threads=no --prefix=%{emscripten_system_local_path} --disable-shared CFLAGS="%{cppflags}"',
        build: 'emmake make',
        install: 'emmake make install',
        clean: '([ -f Makefile ] && make clean) || true'
      },
      {
        name: 'freetype',
        path: 'freetype',
        repository_uri: 'git@github.com:tombo-a2o/freetype.git',
        branch: 'master',
        configure: 'emconfigure %{project_path}/configure --prefix=%{emscripten_system_local_path} --disable-shared --with-zlib=no --with-png=no CPPFLAGS="%{cppflags}"',
        build: 'emmake make -j8',
        install: 'emmake make install',
        clean: 'emmake make clean'
      },
      {
        name: 'Foundation',
        path: 'Foundation',
        repository_uri: 'git@github.com:tombo-a2o/Foundation.git',
        branch: 'feature/emscripten',
        autogen: 'BUILD_DIR=%{build_target_path} make install_header_only',
        build_path: '%{project_path}',
        build: 'STYLE_CPPFLAGS="%{cppflags}" STYLE_LFLAGS="%{lflags}" BUILD_DIR=%{build_target_path} make -j8',
        install: 'STYLE_CPPFLAGS="%{cppflags}" STYLE_LFLAGS="%{lflags}" BUILD_DIR=%{build_target_path} make install',
        clean: 'BUILD_DIR=%{build_target_path} make clean',
        frameworks: %w[
          System/CFNetwork
          System/CoreFoundation
          System/Foundation
        ]
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
        frameworks: %w[
          AVFoundation
          Accounts
          AdSupport
          AddressBook
          AssetsLibrary
          AudioToolbox
          CommonCrypto
          Cocoa
          CoreAudio
          CoreData
          CoreGraphics
          CoreImage
          CoreLocation
          CoreMedia
          CoreMotion
          CoreTelephony
          CoreText
          CoreVideo
          EventKit
          EventKitUI
          GameController
          GameKit
          ImageIO
          IOKit
          MapKit
          MediaPlayer
          MessageUI
          MobileCoreServices
          MultipeerConnectivity
          PassKit
          Onyx2D
          OpenAL
          OpenGLES
          QuartzCore
          QuickLook
          SafariServices
          Security
          Social
          StoreKit
          SystemConfiguration
          TomboAFNetworking
          UIKit
          WebKit
          XCTest
          iAd
        ]
      }
    ]
  },
  xcodebuild: {
    emscripten: {
      file_packager: {
        separate_metadata: false
      }
    },
    static_link_frameworks: %w[
      UIKit Security ImageIO AudioToolbox CommonCrypto SystemConfiguration
      CoreGraphics QuartzCore CFNetwork OpenGLES Onyx2D CoreText
      Social AVFoundation StoreKit CoreFoundation MapKit GameKit MultipeerConnectivity
      MobileCoreServices TomboAFNetworking
    ],
    dynamic_link_frameworks: %w[
      Foundation
    ]
  }
}.freeze

# rubocop:enable Metrics/LineLength
