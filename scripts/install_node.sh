#!/bin/bash
# Install Node.js with nodenv

if [ -z "$NODENV_ROOT" ]; then
  NODENV_ROOT="${HOME}/.nodenv"
fi

if [ ! -e "$NODENV_ROOT" ]; then
  git clone -b v0.3.4 https://github.com/wfarr/nodenv.git $NODENV_ROOT > /dev/null
fi

export PATH="$NODENV_ROOT/bin:$PATH"
eval "$(nodenv init -)"

if nodenv versions | grep "^v6\\.3\\.0\$" > /dev/null; then
  echo "* node.js 6.3.0 with nvm has already been installed"
else
  nodenv install v6.3.0
fi
