#/bin/bash -exu
# Install Node.js woth nvm
if [ ! -d ${HOME}/.nvm ]; then
  curl https://raw.githubusercontent.com/creationix/nvm/v0.24.1/install.sh | bash
  source ${HOME}/.nvm/nvm.sh > /dev/null 2>&1
  nvm install 0.12.2
else
  echo "* nvm is installed"
  source ${HOME}/.nvm/nvm.sh
  if nvm ls 0.12.2 > /dev/null; then
    echo "* node.js 0.12.2 with nvm is installed"
  else
    nvm install 0.12.2
  fi
fi
