# encoding: utf-8
# a2obrew settings

A2O_PATH = File.expand_path(File.dirname(__FILE__))
EMSDK_PATH = "#{A2O_PATH}/emsdk"
DEPENDS_PATH = "#{A2O_PATH}/depends"

A2OCONF = {
  :depends => {
    :path => DEPENDS_PATH,
    :projects => [
      {
        :path => 'libbsd',
        :repository_uri => 'git@github.com:tomboinc/libbsd.git',
        :branch => 'feature/emscripten',
        :autogen => './autogen',
        :configure => "emconfigure ./configure --prefix=#{EMSDK_PATH}/system/local --disable-shared",
        :build => 'make -j8',
        :install => 'make install',
      },
      {
        :path => 'blocks-runtime',
        :repository_uri => 'git@github.com:mheily/blocks-runtime.git',
        :configure => "AR=emar emconfigure ./configure --prefix=#{EMSDK_PATH}/system/local --enable-static --disable-shared",
        :build => 'make -j8',
        :install => 'make install',
      },
      {
        :path => 'objc4',
        :repository_uri => 'git@github.com:tomboinc/objc4.git',
        :branch => 'feature/emscripten',
        :build => 'make -j8',
        :install => 'make install',
      },
      {
        # FIXME: $nativeDir
        :path => 'icu',
        :repository_uri => 'git@github.com:fchiba/icu.git',
        :branch => 'prebuilt',
        :configure => <<CONFIGURE,
emconfigure \
  ../source/configure \
  --enable-static \
  --disable-shared \
  --disable-icuio \
  --disable-layout \
  --disable-tests \
  --disable-samples \
  --disable-extras \
  --disable-tools \
  --with-data-packaging=files \
  --prefix=#{EMSDK_PATH}/system/local \
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
      },
      {
        :path => 'libdispatch',
        :repository_uri => 'git@github.com:tomboinc/libdispatch.git',
        :branch => 'feature/emscripten',
        :build => 'make -j8',
        :install => 'make install',
      },
      {
        :path => 'pixman',
        :repository_uri => 'git://anongit.freedesktop.org/git/pixman.git',
        :autogen => <<AUTOGEN,
sed -e "s/AM_INIT_AUTOMAKE(\[foreign dist-bzip2\])/AM_INIT_AUTOMAKE([foreign dist-bzip2 subdir-objects])/g" configure.ac > tmp
mv tmp configure.ac
NOCONFIGURE=1 ./autogen.sh || autoreconf -i
AUTOGEN
        :configure => "emconfigure ./configure --prefix=#{EMSDK_PATH}/system/local --enable-shared=no --enable-static=yes",
        :build => 'make -j8',
        :install => 'make install',
      },
      {
        :path => 'cairo',
        :repository_uri => 'git://anongit.freedesktop.org/git/cairo',
        :autogen => 'NOCONFIGURE=1 ./autogen.sh',
        :configure => <<EMCONFIGURE,
emconfigure ./configure \
    --prefix=${EMSCRIPTEN}/system/local \
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
      },
      {
        :path => 'openssl',
        :repository_uri => 'git@github.com:gunyarakun/openssl.git',
        :branch => 'feature/emscripten',
        :configure => "emmake sh ./Configure -no-asm no-ssl3 no-comp no-hw no-engine enable-deprecated no-shared no-dso no-gmp --openssldir=#{EMSDK_PATH}/system/local linux-generic32",
        :build => 'emmake make build_libs -j8',
        :install => 'emmake make install_emscripten',
      },
      {
        # TODO: frameworks.txt build
        :path => 'Foundation',
        :repository_uri => 'git@github.com:tomboinc/Foundation.git',
        :branch => 'feature/emscripten',
      },
      {
        # TODO: frameworks.txt build
        :path => 'cocotron',
        :repository_uri => 'git@github.com:tomboinc/cocotron.git',
        :branch => 'feature/emscripten',
      },
      {
        # TODO: UIKit build
        :path => 'Chameleon',
        :repository_uri => 'git@github.com:tomboinc/Chameleon.git',
        :branch => 'feature/with_cocotron',
      },
    ],
  },
}
