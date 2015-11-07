#/bin/bash -exu
# Install Ruby with rbenv

if [ -d ${HOME}/.rbenv ]; then
  echo "* rbenv has already been installed"
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"
else
  git clone https://github.com/sstephenson/rbenv.git ${HOME}/.rbenv
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"
  case "${SHELL}" in
  *"bash")
    echo "export PATH=\"\$HOME/.rbenv/bin:\$PATH\"" >> ${HOME}/.bash_profile
    echo "eval \"\$(rbenv init -)\"" >> ~/.bash_profile
    ;;
  *"zsh")
    echo "export PATH=\"\$HOME/.rbenv/bin:\$PATH\"" >> ${HOME}/.zshrc
    echo "eval \"\$(rbenv init -)\"" >> ~/.zshrc
    ;;
  *)
    echo "Unknown shell"
    exit 1
    ;;
  esac
fi

if [ -d ${HOME}/.rbenv/plugins/ruby-build ]; then
  echo "* ruby-build has already been installed"
  if ! rbenv install --list | grep " 2\\.2\\.2" > /dev/null; then
    cd ${HOME}/.rbenv/plugins/ruby-build && git pull
  fi
else
  git clone git://github.com/sstephenson/ruby-build.git $HOME/.rbenv/plugins/ruby-build
fi

if [ -d ${HOME}/.rbenv/plugins/rbenv-gemset ]; then
  echo "* rbenv-gemset has already been installed"
else
  git clone git://github.com/jf/rbenv-gemset.git $HOME/.rbenv/plugins/rbenv-gemset
fi

if ! gem list --local | grep "bundler " > /dev/null; then
  gem install bundler
  rbenv rehash
fi

bundle install

if rbenv versions --bare | grep "2\\.2\\.2" > /dev/null; then
  echo "* Ruby 2.2.2 with rbenv has already been installed"
else
  rbenv install 2.2.2
fi
