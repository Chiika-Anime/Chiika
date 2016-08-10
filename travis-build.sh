#!/usr/bin/env bash

git clone https://github.com/creationix/nvm.git /tmp/.nvm
source /tmp/.nvm/nvm.sh
nvm install "$NODE_VERSION"
nvm use --delete-prefix "$NODE_VERSION"

if [[ "$TRAVIS_OS_NAME" == "linux" ]]; then
  export DISPLAY=:99.0
  sh -e /etc/init.d/xvfb start
  sleep 3
fi

node --version
npm --version

npm install
./node_modules/.bin/bower install
sleep 3
npm install
sleep 3
npm install
sleep 3
npm install
npm run preparetesting
./node_modules/.bin/mocha --compilers coffee:coffee-script/register ./spec -g "Should launch login"
