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

3. Add `a2obrew init` to your shell to enable shims and autocompletion.

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

## Update

```sh
a2obrew update
```

The command just updates a2obrew itself and dependent repositories.

## Build

For debug version,

```sh
a2obrew build debug
```

For release version,

```sh
a2obrew build release
```

For release version with profiling,

```sh
a2obrew build profiling
```
