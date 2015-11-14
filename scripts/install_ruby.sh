#/bin/bash -exu
# Install Ruby with rbenv

RBENV=${HOME}/.rbenv
GEM=${RBENV}/shims/gem
BUNDLE=${RBENV}/shims/bundle
RUBY_VERSION=2.2.2

if [ -d ${RBENV} ]; then
  echo "* rbenv has already been installed"
  export PATH="$RBENV/bin:$PATH"
  eval "$(rbenv init -)"
else
  git clone https://github.com/sstephenson/rbenv.git ${RBENV}
  export PATH="$RBENV/bin:$PATH"
  eval "$(rbenv init -)"
  case "${SHELL}" in
  *"bash")
    echo "[[ -s \"\${HOME}/.rbenv/bin/rbenv\" ]] && export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\"" >> ${HOME}/.bash_profile
    ;;
  *"zsh")
    echo "[[ -s \"\${HOME}/.rbenv/bin/rbenv\" ]] && export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\"" >> ${HOME}/.zshrc
    echo "export PATH=\"\$HOME/.rbenv/bin:\$PATH\"" >> ${HOME}/.zshrc
    ;;
  *)
    echo "Unknown shell"
    exit 1
    ;;
  esac
fi

if [ -d ${RBENV}/plugins/ruby-build ]; then
  echo "* ruby-build has already been installed"
  if ! rbenv install --list | grep " 2\\.2\\.2" > /dev/null; then
    (cd ${RBENV}/plugins/ruby-build && git pull)
  fi
else
  git clone git://github.com/sstephenson/ruby-build.git $RBENV/plugins/ruby-build
fi

if [ -d ${RBENV}/plugins/rbenv-gemset ]; then
  echo "* rbenv-gemset has already been installed"
  (cd ${RBENV}/plugins/rbenv-gemset && git pull)
else
  git clone git://github.com/jf/rbenv-gemset.git $RBENV/plugins/rbenv-gemset
fi

if rbenv versions --bare | grep -F ${RUBY_VERSION} > /dev/null; then
  echo "* Ruby 2.2.2 with rbenv has already been installed"
  rbenv local ${RUBY_VERSION}
else
  rbenv install ${RUBY_VERSION}
fi

rbenv gemset create ${RUBY_VERSION} a2o

if ! ${GEM} list --local | grep "bundler " > /dev/null; then
  ${GEM} install bundler
  rbenv rehash
fi

${BUNDLE} install
