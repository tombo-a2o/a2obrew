#!/bin/bash
# Install base softwares
sudo aptitude update
sudo aptitude install -y build-essential git-core cmake default-jre autoconf \
  wget curl \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev
