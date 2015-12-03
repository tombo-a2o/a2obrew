#!/bin/bash
# Install Node.js with nvm

if [ -z "$NVM_DIR" ]; then
  NVM_DIR="${HOME}/.nvm"
fi

if [ ! -e "$NVM_DIR" ]; then
  curl https://raw.githubusercontent.com/creationix/nvm/v0.29.0/install.sh | bash
fi

source ${NVM_DIR}/nvm.sh

if ! nvm ls 0.12.2 > /dev/null; then
  echo "* node.js 0.12.2 with nvm has already been installed"
else
  nvm install 0.12.2
fi
