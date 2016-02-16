# Install XCode Command Line Tools
if xcode-select -p > /dev/null; then
  echo "* Xcode Command Line Tool is installed"
else
  curl https://raw.githubusercontent.com/rtrouton/rtrouton_scripts/master/rtrouton_scripts/install_xcode_command_line_tools/install_xcode_command_line_tools.sh | bash
fi

# Install Homebrew
if which brew > /dev/null; then
  echo "* Homebrew is installed"
else
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Install git
if which git > /dev/null; then
  echo "* git is installed"
else
  brew install git
fi

# Install readline
if brew list readline > /dev/null; then
  echo "* readline is installed"
else
  brew install readline
  brew link readline
fi

# Install automake
if brew list automake > /dev/null; then
  echo "* automake is installed"
else
  brew install automake
fi

# Install autoconf
if brew list autoconf > /dev/null; then
  echo "* autoconf is installed"
else
  brew install autoconf
fi

# Install libtool
if brew list libtool > /dev/null; then
  echo "* libtool is installed"
else
  brew install libtool
fi

# Install coreutils
if brew list coreutils > /dev/null; then
  echo "* coreutils is installed"
else
  brew install coreutils
fi

# Install cmake
if brew list cmake > /dev/null; then
  echo "* cmake is installed"
else
  brew install cmake
fi

# Install Ninja
if brew list ninja > /dev/null; then
  echo "* ninja is installed"
else
  brew install ninja
fi

# Install pkg-config
if brew list pkg-config > /dev/null; then
  echo "* pkg-config is installed"
else
  brew install pkg-config
fi
