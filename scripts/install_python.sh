#!/bin/bash -ex
# Install Python2 with pyenv
if [ ! -d ${HOME}/.pyenv ]; then
  curl -L https://raw.githubusercontent.com/yyuu/pyenv-installer/master/bin/pyenv-installer | bash
  case "${SHELL}" in
  *"bash")
    echo "export PATH=\"\$HOME/.pyenv/bin:\$PATH\"" >> ${HOME}/.bash_profile
    echo "eval \"\$(pyenv init -)\"" >> ~/.bash_profile
    echo "eval \"\$(pyenv virtualenv-init -)\"" >> ${HOME}/.bash_profile
    ;;
  *"zsh")
    echo "export PATH=\"\$HOME/.pyenv/bin:\$PATH\"" >> ${HOME}/.zshrc
    echo "eval \"\$(pyenv init -)\"" >> ~/.zshrc
    echo "eval \"\$(pyenv virtualenv-init -)\"" >> ${HOME}/.zshrc
    ;;
  *)
    echo "Unknown shell"
    exit 1
    ;;
  esac
  export PATH="$HOME/.pyenv/bin:$PATH"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
  pyenv install 2.7.9
else
  echo "* pyenv is installed"
  export PATH="$HOME/.pyenv/bin:$PATH"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
  if pyenv versions | grep " 2\\.7\\.9 " > /dev/null; then
    echo "* python 2.7.9 with pyenv is installed"
  else
    pyenv install 2.7.9
  fi
fi
