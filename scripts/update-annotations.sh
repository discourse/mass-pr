#!/bin/bash
set -euxo pipefail

LOAD_PLUGINS=1

cd repo

if [ ! -f "plugin.rb" ]; then
  echo "there is no annotation for themes"
  exit 0
fi

cd ../

if [ ! -d "discourse" ]; then
  echo "cloning discourse core"
  git clone --quiet --depth 1 https://github.com/discourse/discourse.git discourse
fi

cd discourse


echo "symlink"
rm -rf plugins/repo
ln -s ../../repo plugins/repo

bundle install
pnpm install

rake annotate:clean:plugins
