#/bin/bash -exu
# Install Node.js with nvm

if nvm > /dev/null; then
  echo "* nvm has already been installed"
else
  if [ -z "$NVM_DIR" ]; then
    NVM_DIR="${HOME}/.nvm"
  fi
  if [ ! -e "$NVM_DIR" ]; then
    curl https://raw.githubusercontent.com/creationix/nvm/v0.24.1/install.sh | bash
  fi
  source ${NVM_DIR}/nvm.sh > /dev/null 2>&1
fi

if nvm ls 0.12.2 > /dev/null; then
  echo "* node.js 0.12.2 with nvm has already been installed"
else
  nvm install 0.12.2
fi
