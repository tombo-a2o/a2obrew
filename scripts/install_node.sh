#!/bin/bash
# Install Node.js with nodenv

if [ -z "$NODENV_ROOT" ]; then
  NODENV_ROOT="${HOME}/.nodenv"
fi

if [ -d "$NODENV_ROOT" ]; then
  (cd ${NODENV_ROOT} && git pull)
else
  git clone https://github.com/wfarr/nodenv.git $NODENV_ROOT > /dev/null
fi

if [ -d ${NODENV_ROOT}/plugins/node-build ]; then
  echo "* node-build has already been installed"
  if ${NODENV_ROOT}/plugins/node-build/bin/node-build --definitions | grep "^6\\.3\\.0\$" > /dev/null; then
    echo "* node-build can build 6.3.0"
  else
    (cd ${NODENV_ROOT}/plugins/node-build && git pull)
  fi
else
  git clone git://github.com/nodenv/node-build.git $NODENV_ROOT/plugins/node-build
fi

export PATH="$NODENV_ROOT/bin:$PATH"
eval "$(nodenv init -)"

if nodenv versions | grep -E "^v6\\.3\\.0$" > /dev/null; then
  echo "* node.js v6.3.0 with nodenv has already been installed"
else
  nodenv install v6.3.0
fi
