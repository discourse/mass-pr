#!/bin/bash
set -euxo pipefail

cd repo

if [ ! -f "plugin.rb" ]; then
  echo "there is no annotation for themes"
  exit 0
fi

cd ../

echo "cloning discourse core"
if [ ! -d "discourse" ]; then
  git clone --quiet --depth 1 https://github.com/discourse/discourse.git discourse
fi

cd discourse

ln -s ../repo plugins

# TODO: Maybe use annotate:clean:plugins[name]
rake annotate:clean:plugins
