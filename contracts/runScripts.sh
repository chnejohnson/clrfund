#!/bin/bash

set -e

yarn deploy:local
yarn deployTestRound:local
yarn contribute:local --no-compile
yarn vote:local --no-compile

yarn timeTravel:local

export NODE_CONFIG='{"snarkParamsPath": "../../../contracts/snark-params/", "zkutil_bin": "/root/.cargo/bin/zkutil"}'

yarn tally:local --no-compile
yarn finalize:local --no-compile