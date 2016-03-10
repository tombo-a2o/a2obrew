#!/usr/bin/env sh

if [ -d '.git/hooks' ]; then
  ln -s ../../git-hooks/pre-commit .git/hooks
else
  echo "Cannot find .git/hooks"
  exit 1
fi
