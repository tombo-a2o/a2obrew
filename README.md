# a2obrew

## prerequests

- Install Xcode 7.2+

https://developer.apple.com/downloads/

## install

1. Check out a2obrew into `$HOME/a2obrew`.

```sh
git clone git@github.com:tomboinc/a2obrew.git $HOME/a2obrew
```

2. Execute install.sh

```sh
cd $HOME/a2obrew
./install.sh
```

3. Add `$HOME/a2obrew/bin` to your `$PATH` for access to the `a2obrew` command-line utility

```sh
# bash
echo 'export PATH="$HOME/a2obrew/bin:$PATH"' >> ~/.bash_profile
# zsh
echo 'export PATH="$HOME/a2obrew/bin:$PATH"' >> ~/.zshrc
```

4. Add `a2obrew init` to your shell to enable autocompletion and emsdk environment variables. After that, you can use a2obrew and emscripten commands (ex. emcc).

```sh
# bash
echo 'eval "$(a2obrew init -)"' >> ~/.bash_profile
# zsh
echo 'eval "$(a2obrew init -)"' >> ~/.zshrc
```

5. Restart your shell so that PATH changes take effect. (Opening a new
  terminal tab will usually do it.) Now check if a2obrew was set up:

```sh
type a2obrew
```

## Upgrade whole system

Use `a2obrew upgrade`.

```sh
a2obrew upgrade
```

## Build an application

Use `a2obrew xcodebuild`.

```sh
# If there is a2o_project_config.rb
a2obrew xcodebuild
# If you want to use other project config file,
a2obrew xcodebuild -p my_project_config.rb
# if you change build target (ex. debug/release/profile)
a2obrew xcodebuild -t debug
# If you'd like to clean built files, specify -c (--clean)
a2obrew xcodebuild -c
```

## Upload an application

Use `a2obrew platform application_versions create`.

```sh
a2obrew platform application_versions create 67454963-23ad-4868-88bf-3c97fad31685 1.0.1-beta build/release/products
```

## For developers

### Update dependent libraries from git

```sh
# update all
a2obrew libraries update
# update only cocotron
a2obrew libraries update cocotron
```

The command just updates a2obrew itself and dependent repositories.

### Build dependent libraries

`debug` is a target name. The target should be `debug` or `release`. If no target is specified, the target is `release`.


```sh
# autogen is not needed basically after first install
a2obrew libraries autogen
# configure is sometimes needed
a2obrew libraries configure --target=debug
# after modifing some header and source files, you build with this command
a2obrew libraries build --target=debug
# after modifing some header and source files, you build with this command
a2obrew libraries build --target=debug
# You can build specific library
a2obrew libraries build --target=debug cocotron
# You can build specific libraries
a2obrew libraries build --target=debug Foundation cocotron Chameleon
# install built binaries
a2obrew libraries install --target=debug
# clean built binaries
a2obrew libraries clean --target=debug
```
