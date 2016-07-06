# a2obrew & tombocli

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

You can place `a2o_project_config.rb` on the current directory to set variables.

```ruby
cc_flags = '-s FULL_ES2=1 -DGL_GLEXT_PROTOTYPES=1 -DCC_TEXTURE_ATLAS_USE_VAO=0'
html_flags = '-s FULL_ES2=1 -s TOTAL_MEMORY=134217728'
# html_flags += ' --pre-js mem_check.js'
exclude_audio_filter =
distribute_paths = ['./template']

config = {
  version: 1,
  xcodeproj_path: 'Application.xcodeproj',
  xcodeproj_target: 'Application',
  a2o_targets: {
    debug: {
      xcodeproj_build_config: 'Debug',
      flags: {
        cc: "-O0 -DDEBUG=1 -DCD_DEBUG=1 -DCOCOS2D_DEBUG=1", # nilable
        html: "-O0 -s OBJC_DEBUG=1 --emrun" # nilable
      },
      emscripten_shell_path: 'shell.html', # nilable
      distribute_paths: ['./a2o_files'], # nilable
      resource_filter: lambda { |path| path !~ /\.mp3$/ } # nilable
    }
  }
}

config
```

## Upload an application

Use `tombocli application_versions create`.

```sh
tombocli application_versions create 67454963-23ad-4868-88bf-3c97fad31685 1.0.1-beta build/release/products
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
