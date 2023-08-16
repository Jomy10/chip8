#!/usr/bin/env sh

# https://gist.github.com/myusuf3/7f645819ded92bda6677?permalink_comment_id=4175902#gistcomment-4175902

# TODO: if powershel: https://gist.github.com/myusuf3/7f645819ded92bda6677?permalink_comment_id=4485454#gistcomment-4485454

if [[ $1 == '' ]]; then
  echo "Missing path to submodule"
  exit 1
fi

git submodule deinit -f $1

rm -rf ".git/modules/$1"

git rm -f $1
