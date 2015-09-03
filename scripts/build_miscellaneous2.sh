#!/bin/bash -exu
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./Foundation ]; then
  git clone git@github.com:tomboinc/Foundation.git --branch feature/emscripten
fi

cd Foundation
git pull

repos="AVFoundation Accounts AdSupport CommonCrypto CoreAudio AudioToolbox CoreLocation CoreText GameKit ImageIO MapKit MobileCoreServices MultipeerConnectivity Social StoreKit SystemConfiguration"

for repo in $repos; do
    (cd System/$repo; make install)
done
