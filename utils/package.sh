#!/bin/bash -eu

#eval "$(bin/a2obrew init -)"
#bin/a2obrew libraries autogen
#bin/a2obrew libraries configure
#bin/a2obrew libraries build
#bin/a2obrew libraries install

hashfile=`pwd`/commit-hash.yaml
rm -f ${hashfile}
for i in `find . -name .git -exec dirname {} \;`; do
  pushd $i > /dev/null
  # record hash
  echo "- dir: $i" >> ${hashfile}
  echo "  repos: `git remote get-url origin`" >> ${hashfile}
  echo "  hash: `git rev-parse HEAD`" >> ${hashfile}
  popd > /dev/null
done

filelist=`mktemp`
name=a2o-`date +%Y%m%d-%H%M%S`
zip=`pwd`/archive/${name}.zip

mkdir -p `dirname ${zip}`

for i in `find . -name .git -exec dirname {} \;`; do
  pushd $i > /dev/null
  # source files
  git ls-files | grep -v -e buildLinux -e buildMac | sed -e 's|^|'"$i"'/|' >> ${filelist}
  # binaries
  git ls-files -o -x *.o -x *.d -x *.dylib -x "archive/*.zip" -x sample_projects | grep -v -e build/debug -e build/profile -e build_feature-objc_64/lib | sed -e 's|^|'"$i"'/|' >> ${filelist}
  popd > /dev/null
done

#cat $filelist
zip --symlinks -r $zip . -i @$filelist
