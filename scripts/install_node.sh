#/bin/bash -exu
# Install Node.js woth nvm

if which nvm > /dev/null; then
  echo "* nvm has already been installed"
else
  if [ ! -d ${HOME}/.nvm ]; then
    curl https://raw.githubusercontent.com/creationix/nvm/v0.24.1/install.sh | bash
  fi
  source ${HOME}/.nvm/nvm.sh > /dev/null 2>&1
fi

if nvm ls 0.12.2 > /dev/null; then
  echo "* node.js 0.12.2 with nvm has already been installed"
else
  nvm install 0.12.2
fi
