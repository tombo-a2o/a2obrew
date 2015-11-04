# encoding: utf-8
# a2obrew settings

A2O_PATH = File.expand_path(File.dirname(__FILE__))

A2OCONF = {
  :depends => {
    :path => "#{A2O_PATH}/depends",
    :projects => [
      {
        :name => 'libbsd',
        :path => 'libbsd',
        :repository_uri => 'git@github.com:tomboinc/libbsd.git',
        :branch => 'feature/emscripten',
        :autogen => './autogen',
        :configure => 'emconfigure %{project_path}/configure --prefix=%{emsdk_path}/system/local --disable-shared',
        :build => 'make -j8',
        :install => 'make install',
        :clean => 'make clean',
      },
      {
        :name => 'blocks-runtime',
        :path => 'blocks-runtime',
        :repository_uri => 'git@github.com:mheily/blocks-runtime.git',
        :autogen => 'autoreconf -i || autoreconf -i',
        :configure => 'AR=emar emconfigure %{project_path}/configure --prefix=%{emsdk_path}/system/local --enable-static --disable-shared',
        :build => 'make -j8',
        :install => 'make install',
        :clean => 'make clean',
      },
      {
        :name => 'objc4',
        :path => 'objc4',
        :repository_uri => 'git@github.com:tomboinc/objc4.git',
        :branch => 'feature/emscripten',
        :build => 'make -j8',
        :install => 'make install',
        :clean => 'make clean',
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
  --prefix=%{emsdk_path}/system/local \
  --with-cross-build=`pwd`/../$nativeDir
CONFIGURE
        :build => <<BUILD,
emmake ARFLAGS=rv -j8
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
cd ..
BUILD
        :install => 'make install',
        :clean => 'make clean',
      },
      {
        :name => 'libdispatch',
        :path => 'libdispatch',
        :repository_uri => 'git@github.com:tomboinc/libdispatch.git',
        :branch => 'feature/emscripten',
        :build => 'make -j8',
        :install => 'make install',
        :clean => 'make clean',
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
        :configure => 'emconfigure %{project_path}/configure --prefix=%{emsdk_path}/system/local --enable-shared=no --enable-static=yes',
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
    --prefix=%{emsdk_path}/system/local \
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
    CFLAGS="-DCAIRO_NO_MUTEX=1"
EMCONFIGURE
        :build => 'make -j8',
        :install => 'make install',
        :clean => 'make clean',
      },
      {
        :name => 'openssl',
        :path => 'openssl',
        :repository_uri => 'git@github.com:gunyarakun/openssl.git',
        :branch => 'feature/emscripten',
        :configure => 'emconfigure sh %{project_path}/Configure -no-asm no-ssl3 no-comp no-hw no-engine enable-deprecated no-shared no-dso no-gmp --openssldir=%{emsdk_path}/system/local linux-generic32',
        :build_path => '%{project_path}', # ignores target X( because openssl uses non-standard perl Configure
        :build => 'emmake make build_libs -j8',
        :install => 'emmake make install_emscripten',
        :clean => 'make clean',
      },
      {
        :name => 'freetype',
        :path => 'freetype',
        :repository_uri => 'git@github.com:fchiba/freetype.git',
        :branch => 'master',
        :configure => 'emconfigure %{project_path}/configure --prefix=%{emsdk_path}/system/local --disable-shared --with-zlib=no --with-png=no',
        :build => 'emmake make -j8',
        :install => 'emmake make install',
        :clean => 'emmake make clean',
      },
      {
        :name => 'Foundation',
        :path => 'Foundation',
        :repository_uri => 'git@github.com:tomboinc/Foundation.git',
        :branch => 'feature/emscripten',
        :build => 'make -j8',
        :install => 'make install',
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
        :build => 'make -j8',
        :install => 'make install',
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
        # TODO: UIKit build
        :name => 'Chameleon',
        :path => 'Chameleon',
        :repository_uri => 'git@github.com:tomboinc/Chameleon.git',
        :branch => 'feature/with_cocotron',
        :build => 'make -j8',
        :install => 'make install',
        :frameworks => %w(
          UIKit
        ),
      },
    ],
  },
}
