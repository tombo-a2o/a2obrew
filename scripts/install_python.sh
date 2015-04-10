#/bin/sh
# Install Python2 with pyenv
if [ ! -d ~/.pyenv ]; then
  curl -L https://raw.githubusercontent.com/yyuu/pyenv-installer/master/bin/pyenv-installer | bash
  export PATH="$HOME/.pyenv/bin:$PATH"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
  pyenv install 2.7.9
else
  echo "* pyenv is installed"
  if pyenv versions | grep " 2\\.7\\.9 " > /dev/null; then
    echo "* python 2.7.9 with pyenv is installed"
  else
    pyenv install 2.7.9
  fi
fi
