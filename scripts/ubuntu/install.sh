#!/bin/sh
# Install base softwares
sudo aptitude update
sudo aptitude install -y build-essential git-core cmake default-jre \
  wget curl \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev
