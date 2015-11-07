# a2obrew

## install

1. Check out a2obrew into `$HOME/a2obrew`.

```sh
git clone git@github.com:tomboinc/a2obrew.git $HOME/a2obrew
```

2. Add `$HOME/a2obrew/bin` to your `$PATH` for access to the `a2obrew` command-line utility

```sh
# bash
echo 'export PATH="$HOME/a2obrew/bin:$PATH"' >> ~/.bash_profile
# zsh
echo 'export PATH="$HOME/a2obrew/bin:$PATH"' >> ~/.zshrc
```

3. Add `a2obrew init` to your shell to enable autocompletion and emsdk environment variables.

```sh
# bash
echo 'eval "$(a2obrew init -)"' >> ~/.bash_profile
# zsh
echo 'eval "$(a2obrew init -)"' >> ~/.zshrc
```

4. Restart your shell so that PATH changes take effect. (Opening a new
  terminal tab will usually do it.) Now check if a2obrew was set up:

```sh
type a2obrew
```

## Update dependent libraries from git

```sh
# update all
a2obrew update
# update only cocotron
a2obrew update cocotron
```

The command just updates a2obrew itself and dependent repositories.

## Build

`debug` is a target name. The target should be `debug` or `release`. If no target is specified, the target is `release`.


```sh
# autogen is not needed basically after first install
a2obrew autogen
# configure is sometimes needed
a2obrew configure --target=debug
# after modifing some header and source files, you build with this command
a2obrew build --target=debug
# after modifing some header and source files, you build with this command
a2obrew build --target=debug
# You can build specific library
a2obrew build --target=debug cocotron
# install built binaries
a2obrew install --target=debug
# clean built binaries
a2obrew clean --target=debug
```
