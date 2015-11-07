# encoding: utf-8
# a2obrew settings

A2O_PATH = File.expand_path(File.dirname(__FILE__))

ICU_NATIVE_DIR = `uname` =~ /\ADarwin/ ? 'buildMac' : 'buildLinux'

A2OCONF = {
  :targets => {
    :debug => {
      # :cppflags => '-g -O0 -DDEBUG',
      :cppflags => '-O0 -DDEBUG',
    },
    :release => {
      :cppflags => '-O2',
    },
  },
  :depends => {
    :path => "#{A2O_PATH}/depends",
    :projects => [
      {
        :name => 'libbsd',
        :path => 'libbsd',
        :repository_uri => 'git@github.com:tomboinc/libbsd.git',
        :branch => 'feature/emscripten',
        :autogen => './autogen',
        :configure => 'emconfigure %{project_path}/configure --prefix=%{emscripten_system_local_path} --disable-shared CFLAGS="%{cppflags}"',
        :build => 'make -j8',
        :install => 'make install',
        :clean => 'make clean',
      },
      {
        :name => 'blocks-runtime',
        :path => 'blocks-runtime',
        :repository_uri => 'git@github.com:mheily/blocks-runtime.git',
        :autogen => 'autoreconf -i || autoreconf -i',
        :configure => 'AR=emar emconfigure %{project_path}/configure --prefix=%{emscripten_system_local_path} --enable-static --disable-shared CFLAGS="%{cppflags}"',
        :build => 'make -j8 && rm a.out*',
        :install => 'make install',
        :clean => 'make clean',
      },
      {
        :name => 'objc4',
        :path => 'objc4',
        :repository_uri => 'git@github.com:tomboinc/objc4.git',
        :branch => 'feature/emscripten',
        :build_path => '%{project_path}',
        :build => 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make -j8',
        :install => 'BUILD=%{build_target_path} make install',
        :clean => 'BUILD=%{build_target_path} make clean',
      },
      {
        :name => 'icu',
        :path => 'icu',
        :repository_uri => 'git@github.com:fchiba/icu.git',
        :branch => 'prebuilt',
        :configure => <<CONFIGURE,
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
  --with-data-packaging=files \
  --prefix=%{emscripten_system_local_path} \
  --with-cross-build=`pwd`/../#{ICU_NATIVE_DIR} \
  CPPFLAGS="%{cppflags}"
CONFIGURE
        :build_path => '%{project_path}/buildEmscripten%{target}',
        :build_target_path => '%{project_path}/buildEmscripten%{target}',
        :build => <<BUILD,
emmake make ARFLAGS=rv -j8
cd lib
for archive in `ls *.a`; do
    bc=`basename ${archive} .a`.bc
    llvm-ar t ${archive} > files
    llvm-ar x ${archive}
    llvm-link -o ${bc} `cat files`
    rm ${archive}
    llvm-ar r ${archive} ${bc}
    rm `cat files`
    rm files
    rm -f ${bc}
done
BUILD
        :install => 'make install',
      },
      {
        :name => 'libdispatch',
        :path => 'libdispatch',
        :repository_uri => 'git@github.com:tomboinc/libdispatch.git',
        :branch => 'feature/emscripten',
        :build_path => '%{project_path}',
        :build => 'OPT_CFLAGS="%{cppflags}" BUILD=%{build_target_path} make -j8',
        :install => 'BUILD=%{build_target_path} make install',
        :clean => 'BUILD=%{build_target_path} make clean',
      },
      {
        :name => 'pixman',
        :path => 'pixman',
        :repository_uri => 'git://anongit.freedesktop.org/git/pixman.git',
        :autogen => <<AUTOGEN,
sed -e "s/AM_INIT_AUTOMAKE(\\\[foreign dist-bzip2\\\])/AM_INIT_AUTOMAKE([foreign dist-bzip2 subdir-objects])/g" configure.ac > tmp
mv tmp configure.ac
NOCONFIGURE=1 ./autogen.sh || autoreconf -i
AUTOGEN
        :configure => 'emconfigure %{project_path}/configure --prefix=%{emscripten_system_local_path} --enable-shared=no --enable-static=yes CPPFLAGS="%{cppflags}"',
        :build => 'make -j8',
        :install => 'make install',
        :clean => 'make clean',
      },
      {
        :name => 'cairo',
        :path => 'cairo',
        :repository_uri => 'git://anongit.freedesktop.org/git/cairo',
        :autogen => 'NOCONFIGURE=1 ./autogen.sh',
        :configure => <<EMCONFIGURE,
emconfigure %{project_path}/configure \
    --prefix=%{emscripten_system_local_path} \
    --enable-shared=no \
    --enable-static=yes \
    --enable-gl=yes \
    --enable-pthread=no \
    --enable-png=no \
    --enable-script=no \
    --enable-interpreter=no \
    --enable-ps=no \
    --enable-pdf=no \
    --enable-svg=no \
    --host=x86_64-apple-darwin14.5.0 \
    CFLAGS="-DCAIRO_NO_MUTEX=1" \
    CPPFLAGS="%{cppflags}"
EMCONFIGURE
        :build => 'make -j8',
        :install => 'make install',
        :clean => 'make clean',
      },
      {
        # NOTE: openssl doesn't support target
        :name => 'openssl',
        :path => 'openssl',
        :repository_uri => 'git@github.com:gunyarakun/openssl.git',
        :branch => 'feature/emscripten',
        :configure => 'emconfigure sh %{project_path}/Configure -no-asm no-ssl3 no-comp no-hw no-engine enable-deprecated no-shared no-dso no-gmp --openssldir=%{emscripten_system_local_path} linux-generic32',
        :build_path => '%{project_path}',
        :build_target_path => '%{project_path}',
        :build => 'emmake make build_libs -j8',
        :install => 'emmake make install_emscripten',
        :clean => 'make clean',
      },
      {
        :name => 'freetype',
        :path => 'freetype',
        :repository_uri => 'git@github.com:fchiba/freetype.git',
        :branch => 'master',
        :configure => 'emconfigure %{project_path}/configure --prefix=%{emscripten_system_local_path} --disable-shared --with-zlib=no --with-png=no CPPFLAGS=%{cppflags}',
        :build => 'emmake make -j8',
        :install => 'emmake make install',
        :clean => 'emmake make clean',
      },
      {
        :name => 'Foundation',
        :path => 'Foundation',
        :repository_uri => 'git@github.com:tomboinc/Foundation.git',
        :branch => 'feature/emscripten',
        :autogen => 'BUILD_DIR=%{build_target_path} make install_header_only',
        :build_path => '%{project_path}',
        :build => 'STYLE_CPPFLAGS="%{cppflags}" BUILD_DIR=%{build_target_path} make -j8',
        :install => 'BUILD_DIR=%{build_target_path} make install',
        :clean => 'BUILD_DIR=%{build_target_path} make clean',
        :frameworks => %w(
          System/Accounts
          System/AdSupport
          System/AudioToolbox
          System/AVFoundation
          System/CFNetwork
          System/CoreAudio
          System/CoreFoundation
          System/CoreLocation
          System/Foundation
          System/GameKit
          System/ImageIO
          System/OpenGLES
          System/MapKit
          System/MobileCoreServices
          System/MultipeerConnectivity
          System/Security
          System/Social
          System/StoreKit
          System/SystemConfiguration
        ),
      },
      {
        :name => 'cocotron',
        :path => 'cocotron',
        :repository_uri => 'git@github.com:tomboinc/cocotron.git',
        :branch => 'feature/emscripten',
        :autogen => 'BUILD_DIR=%{build_target_path} make install_header_only',
        :build_path => '%{project_path}',
        :build => 'STYLE_CPPFLAGS="%{cppflags}" BUILD_DIR=%{build_target_path} make -j8',
        :install => 'BUILD_DIR=%{build_target_path} make install',
        :clean => 'BUILD_DIR=%{build_target_path} make clean',
        :frameworks => %w(
          AppKit
          CommonCrypto
          CoreData
          CoreGraphics
          CoreText
          Onyx2D
          QuartzCore
        ),
      },
      {
        :name => 'Chameleon',
        :path => 'Chameleon',
        :repository_uri => 'git@github.com:tomboinc/Chameleon.git',
        :branch => 'feature/with_cocotron',
        :autogen => 'BUILD_DIR=%{build_target_path} make install_header_only',
        :build_path => '%{project_path}',
        # FIXME: now -O2 doesn't work on Chameleon, so set static CPPFLAGS
        # :build => 'STYLE_CPPFLAGS="%{cppflags}" BUILD_DIR=%{build_target_path} make -j8',
        :build => 'STYLE_CPPFLAGS="-O0 -DDEBUG" BUILD_DIR=%{build_target_path} make -j8',
        :install => 'BUILD_DIR=%{build_target_path} make install',
        :clean => 'BUILD_DIR=%{build_target_path} make clean',
        :frameworks => %w(
          UIKit
        ),
      },
    ],
  },
}
